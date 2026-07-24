#!/usr/bin/env bash
set -euo pipefail

# Reset CLI contract: root help advertises the three modes, `reset` without
# a mode only shows usage, every mode dispatches to the canonical
# implementation, unknown modes/options fail, --dry-run performs zero
# mutations, each mode requires its exact confirmation phrase, and the old
# reset-node.sh behavior (bare `RESET` confirmation, no mode) is gone.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

fail() {
  echo "RESET CLI TEST ERROR: $*" >&2
  exit 1
}

# shellcheck disable=SC1091
. "$REPO_ROOT/tests/lib/reset-harness.sh"
reset_harness_init

# --- 1. root CLI help lists the three reset modes -------------------------
help_output="$(bash "$REPO_ROOT/lisa-edge" help)"
grep -Fq 'reset data' <<<"$help_output" || fail "root help must list 'reset data'"
grep -Fq 'reset provisioning' <<<"$help_output" || fail "root help must list 'reset provisioning'"
grep -Fq 'reset factory' <<<"$help_output" || fail "root help must list 'reset factory'"
grep -Fq 'Erase service runtime state and redeploy with current configuration' <<<"$help_output" ||
  fail "root help must describe reset data"
grep -Fq 'Remove LISA state/configuration and return to first-boot provisioning' <<<"$help_output" ||
  fail "root help must describe reset provisioning"
grep -Fq 'Reinstall the Production OS through the Rescue Layer' <<<"$help_output" ||
  fail "root help must describe reset factory"

# --- 2. `lisa-edge reset` shows reset usage only, mutates nothing ---------
reset_harness_seed_provisioned_host
snapshot_before="$(cd "$WORK" && find repo dataroot systemd varlib sbin | sort)"

run_reset --
[ "$RC" -eq 2 ] || fail "bare 'reset' must exit 2, got $RC"
output_contains 'Usage: lisa-edge reset <mode> [--dry-run]' ||
  fail "bare 'reset' must print reset usage"
output_contains 'LISA Edge reset plan' && fail "bare 'reset' must not print a reset plan"
[ -s "$LOG" ] && fail "bare 'reset' must not invoke docker/systemctl/findmnt"

run_reset -- --help
[ "$RC" -eq 0 ] || fail "'reset --help' must exit 0, got $RC"
output_contains 'Usage: lisa-edge reset <mode> [--dry-run]' ||
  fail "'reset --help' must print reset usage"

# --- 4. unknown modes and options fail safely ------------------------------
run_reset -- bogus-mode
[ "$RC" -eq 2 ] || fail "unknown reset mode must exit 2, got $RC"
output_contains 'unknown reset mode: bogus-mode' || fail "unknown mode must be named in the error"

run_reset -- data --bogus-option
[ "$RC" -eq 2 ] || fail "unknown reset option must exit 2, got $RC"
output_contains 'unknown reset option: --bogus-option' || fail "unknown option must be named in the error"

run_reset -- data provisioning
[ "$RC" -eq 2 ] || fail "two reset modes at once must exit 2, got $RC"

snapshot_after="$(cd "$WORK" && find repo dataroot systemd varlib sbin | sort)"
[ "$snapshot_before" = "$snapshot_after" ] ||
  fail "usage/error paths must not change any file"

# --- 3 + 29. each mode dispatches to the canonical implementation ---------
# The plan header is printed by ops/deploy/reset-node.sh and reports the
# repository root resolved from the script location inside the fake repo.
for mode in data provisioning factory; do
  : > "$LOG"
  run_reset -- "$mode" --dry-run
  [ "$RC" -eq 0 ] || fail "'reset $mode --dry-run' must exit 0, got $RC"
  grep -Eq "Reset mode:[[:space:]]+$mode" <<<"$OUTPUT" ||
    fail "'reset $mode' must dispatch to the canonical reset implementation"
  grep -Eq "Repository:[[:space:]]+$FAKE_REPO" <<<"$OUTPUT" ||
    fail "the canonical implementation must resolve the repo root from its own location"
done

# --- 5. --dry-run performs zero mutations ----------------------------------
: > "$LOG"
snapshot_before="$(cd "$WORK" && find repo dataroot systemd varlib sbin | sort)"
for mode in data provisioning factory; do
  run_reset -- "$mode" --dry-run
  [ "$RC" -eq 0 ] || fail "'reset $mode --dry-run' must exit 0"
  output_contains '[dry-run]' || fail "dry-run must label itself"
done
snapshot_after="$(cd "$WORK" && find repo dataroot systemd varlib sbin | sort)"
[ "$snapshot_before" = "$snapshot_after" ] || fail "--dry-run must not create or delete files"
[ -f "$DATAROOT/secrets/generated.token" ] || fail "--dry-run must not delete runtime data"
[ -f "$FAKE_REPO/.env" ] || fail "--dry-run must not delete .env"
for forbidden in ' down ' ' rm ' ' stop ' ' enable ' ' disable ' 'daemon-reload' 'reset-failed'; do
  grep -Fq -- "$forbidden" "$LOG" &&
    fail "--dry-run must not run mutating commands (found:$forbidden)"
done

# --- 6 + 30. exact confirmation phrases; old bare-RESET bypass is gone -----
confirm_rejected() {
  local mode="$1"
  local phrase="$2"
  : > "$LOG"
  run_reset --stdin "$phrase" -- "$mode"
  [ "$RC" -ne 0 ] || fail "'reset $mode' with confirmation '$phrase' must abort"
  output_contains 'Aborted. No changes were made.' ||
    fail "'reset $mode' with confirmation '$phrase' must report a clean abort"
  [ -f "$DATAROOT/secrets/generated.token" ] ||
    fail "aborted 'reset $mode' must not delete data"
  [ -f "$FAKE_REPO/.env" ] || fail "aborted 'reset $mode' must not delete .env"
  log_lacks 'docker rm' || fail "aborted 'reset $mode' must not remove containers"
  log_lacks ' down ' || fail "aborted 'reset $mode' must not run compose down"
}

# The legacy reset-node.sh accepted the bare phrase RESET; it must no
# longer be accepted anywhere.
confirm_rejected data 'RESET'
confirm_rejected data 'RESET LISA'
confirm_rejected data 'reset data'
confirm_rejected data ''
confirm_rejected provisioning 'RESET'
confirm_rejected provisioning 'RESET DATA'
confirm_rejected provisioning 'yes'

# The old implementation ran without any mode argument; the canonical
# script must now refuse and only print usage.
: > "$LOG"
rc=0
legacy_output="$(printf 'RESET\n' | bash "$FAKE_REPO/ops/deploy/reset-node.sh" 2>&1)" || rc=$?
[ "$rc" -eq 2 ] || fail "reset-node.sh without a mode must exit 2, got $rc"
grep -Fq 'Usage: lisa-edge reset <mode> [--dry-run]' <<<"$legacy_output" ||
  fail "reset-node.sh without a mode must only print usage"
[ -f "$DATAROOT/secrets/generated.token" ] || fail "legacy invocation must not delete data"

echo "Reset CLI contract tests passed."
