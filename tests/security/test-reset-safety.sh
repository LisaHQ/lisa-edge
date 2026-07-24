#!/usr/bin/env bash
set -euo pipefail

# Reset safety guardrails: unsafe DATA_ROOT values, traversal and symlink
# attacks, repository-checkout protection, nested-mount fail-closed
# behavior, unreadable mount tables, and the static absence of global
# Docker cleanup and disk-wipe tooling in the canonical implementation.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

fail() {
  echo "RESET SAFETY TEST ERROR: $*" >&2
  exit 1
}

# shellcheck disable=SC1091
. "$REPO_ROOT/tests/lib/reset-harness.sh"

write_env_with_data_root() {
  cat > "$FAKE_REPO/.env" <<ENV
DATA_ROOT='$1'
COMPOSE_PROJECT_NAME='lisa-edge'
LISA_COMPOSE_SERVICES='mqtt uptime-kuma'
ENV
}

expect_rejected() {
  local description="$1"
  shift
  run_reset --stdin 'RESET DATA' -- "$@"
  [ "$RC" -ne 0 ] || fail "$description must be rejected (got rc=0): $OUTPUT"
  # Rejection must happen before anything is stopped or deleted.
  log_lacks 'systemctl stop' || fail "$description: nothing may be stopped"
  log_lacks ' down ' || fail "$description: compose down must not run"
  log_lacks 'docker rm' || fail "$description: no container may be removed"
}

# --- 7. unsafe DATA_ROOT values are rejected -------------------------------
reset_harness_init
canary="$WORK/canary"
printf 'canary\n' > "$canary"

for bad_root in '/' '' 'relative/path' '/etc' '/usr/lib' '/var' '/srv' '/tmp/..'; do
  : > "$LOG"
  write_env_with_data_root "$bad_root"
  expect_rejected "DATA_ROOT='$bad_root'" data
done
[ -f "$canary" ] || fail "canary vanished during unsafe DATA_ROOT tests"

# --- 8. traversal and symlink attacks are rejected --------------------------
: > "$LOG"
write_env_with_data_root "$WORK/dataroot/../../../etc"
expect_rejected 'traversal DATA_ROOT' data

# A DATA_ROOT symlink that resolves into a protected tree must be refused
# even though the visible path looks harmless.
ln -sfn /etc "$WORK/innocent-looking"
: > "$LOG"
write_env_with_data_root "$WORK/innocent-looking"
expect_rejected 'symlinked DATA_ROOT into /etc' data
[ -d /etc ] || fail "/etc disappeared - the symlink guard failed catastrophically"

# The repository checkout itself must never be a deletion root.
for repo_root_attack in "$FAKE_REPO" "$WORK"; do
  : > "$LOG"
  write_env_with_data_root "$repo_root_attack"
  expect_rejected "DATA_ROOT covering the repository ($repo_root_attack)" data
done
[ -f "$FAKE_REPO/ops/deploy/reset-node.sh" ] || fail "repository was damaged"

# provisioning must obey the same validation with a hostile .env value.
: > "$LOG"
write_env_with_data_root '/'
run_reset --stdin 'RESET LISA' -- provisioning
[ "$RC" -ne 0 ] || fail "provisioning with DATA_ROOT=/ must be rejected"

# --- 9. nested mount conditions fail closed --------------------------------
reset_harness_init
reset_harness_seed_provisioned_host

printf '/\n/tmp\n%s\n' "$DATAROOT/docker/volumes/nas-mount" > "$FINDMNT_TABLE"
: > "$LOG"
run_reset --stdin 'RESET DATA' -- data
[ "$RC" -ne 0 ] || fail "a mount below a deletion target must abort reset data"
output_contains 'mounted filesystems exist below' ||
  fail "the nested-mount refusal must name the problem"
[ -f "$DATAROOT/docker/volumes/matter-server/fabric.json" ] ||
  fail "nested-mount refusal must happen before deletion"
log_lacks 'systemctl stop' ||
  fail "nested-mount refusal must happen before services are stopped"

printf '/\n/tmp\n%s\n' "$DATAROOT/backups/nas" > "$FINDMNT_TABLE"
: > "$LOG"
run_reset --stdin 'RESET LISA' -- provisioning
[ "$RC" -ne 0 ] || fail "a mount below DATA_ROOT must abort reset provisioning"
[ -f "$FAKE_REPO/.env" ] || fail "nested-mount refusal must preserve .env"
[ -f "$DATAROOT/backups/lisa-edge-backup-1.tar.gz" ] ||
  fail "nested-mount refusal must preserve the (possibly external) backups"

# An unreadable mount table must also fail closed.
printf '/\n/tmp\n' > "$FINDMNT_TABLE"
: > "$LOG"
run_reset --stdin 'RESET DATA' --env RESET_TEST_FINDMNT_FAIL=1 -- data
[ "$RC" -ne 0 ] || fail "an unreadable mount table must abort the reset"
output_contains 'Cannot read the mount table' ||
  fail "the mount-table failure must be reported"
[ -f "$DATAROOT/secrets/generated.token" ] ||
  fail "mount-table failure must abort before deletion"

# --- 10. external BACKUP_DEST is never part of the deletion scope ----------
reset_harness_init
reset_harness_seed_provisioned_host "$EXTERNAL_BACKUPS"
run_reset --stdin 'RESET DATA' -- data
[ "$RC" -eq 0 ] || fail "reset data with external BACKUP_DEST must succeed: $OUTPUT"
[ -f "$EXTERNAL_BACKUPS/lisa-edge-backup-external.tar.gz" ] ||
  fail "external BACKUP_DEST must be preserved by reset data"
grep -Eq "BACKUP_DEST:[[:space:]]+$EXTERNAL_BACKUPS \(outside DATA_ROOT\)" <<<"$OUTPUT" ||
  fail "the plan must state that BACKUP_DEST is outside DATA_ROOT"

# A DATA_ROOT/backups symlink pointing at external storage must be removed
# as a LINK by reset provisioning, never followed into the target.
reset_harness_init
reset_harness_seed_provisioned_host
rm -rf "$DATAROOT/backups"
ln -sfn "$EXTERNAL_BACKUPS" "$DATAROOT/backups"
run_reset --stdin 'RESET LISA' -- provisioning
[ "$RC" -eq 0 ] || fail "provisioning with a backups symlink must succeed: $OUTPUT"
[ ! -e "$DATAROOT/backups" ] || fail "the backups symlink must be removed"
[ -f "$EXTERNAL_BACKUPS/lisa-edge-backup-external.tar.gz" ] ||
  fail "deletion must never follow a symlink out of DATA_ROOT"

# --- static guarantees on the canonical implementation ---------------------
RESET_SCRIPT="$REPO_ROOT/ops/deploy/reset-node.sh"

# 25. no global Docker cleanup of any kind.
for forbidden in 'system prune' 'volume prune' 'network prune' 'image prune' \
  'builder prune' 'docker rmi'; do
  grep -Fq -- "$forbidden" "$RESET_SCRIPT" &&
    fail "reset-node.sh must never contain: $forbidden"
done

# 28. no disk-wipe tooling: the factory path is a guarded handoff only.
for forbidden in 'dd if=' 'mkfs' 'wipefs' 'sgdisk' 'blkdiscard'; do
  grep -Fq -- "$forbidden" "$RESET_SCRIPT" &&
    fail "reset-node.sh must never contain disk tooling: $forbidden"
done

# rm -rf callers must go through the validated delete_tree helper: the only
# recursive deletion in the script is the guarded one inside delete_tree.
rm_rf_count="$(grep -c 'rm -rf' "$RESET_SCRIPT")" || true
[ "$rm_rf_count" -eq 1 ] ||
  fail "reset-node.sh must keep exactly one guarded recursive deletion (found $rm_rf_count)"
grep -Fq 'rm -rf --one-file-system --' "$RESET_SCRIPT" ||
  fail "the guarded deletion must refuse to cross filesystems"

echo "Reset safety guardrail tests passed."
