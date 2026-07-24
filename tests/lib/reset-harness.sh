#!/usr/bin/env bash

# Shared harness for the reset lifecycle tests. Builds an isolated fake
# repository under /tmp containing the REAL canonical reset implementation
# (ops/deploy/reset-node.sh, the root CLI and the shared libraries) plus
# stubbed deploy/provisioning scripts, and provides PATH shims for docker,
# systemctl and findmnt that record every invocation.
#
# Nothing here ever touches /etc, /var/lib, /usr/local, /opt, /srv, the
# Docker daemon, systemd, a bootloader or a disk: every mutating command is
# a stub and every path lives below a private mktemp directory.

RESET_HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESET_REPO_ROOT="$(cd "$RESET_HARNESS_DIR/../.." && pwd)"

reset_harness_init() {
  WORK="$(TMPDIR=/tmp mktemp -d /tmp/lisa-reset-test.XXXXXX)"
  FAKE_REPO="$WORK/repo"
  BIN="$WORK/bin"
  LOG="$WORK/calls.log"
  STATE="$WORK/state"
  SYSTEMD_DIR="$WORK/systemd"
  STATE_DIR="$WORK/varlib"
  SBIN_DIR="$WORK/sbin"
  RESCUE_ROOT="$WORK/rescue-root"
  DATAROOT="$WORK/dataroot"
  EXTERNAL_BACKUPS="$WORK/external-backups"
  FINDMNT_TABLE="$WORK/findmnt-table"

  mkdir -p "$BIN" "$STATE" "$SYSTEMD_DIR" "$STATE_DIR" "$SBIN_DIR" \
    "$EXTERNAL_BACKUPS"
  : > "$LOG"
  printf '/\n/tmp\n' > "$FINDMNT_TABLE"

  reset_harness_build_fake_repo
  reset_harness_build_stubs

  export RESET_TEST_LOG="$LOG"
  export RESET_TEST_STATE="$STATE"
  export RESET_TEST_FINDMNT_TABLE="$FINDMNT_TABLE"

  # shellcheck disable=SC2064
  trap "rm -rf '$WORK'" EXIT
}

reset_harness_build_fake_repo() {
  local file
  local copies=(
    lisa-edge
    ops/deploy/reset-node.sh
    ops/deploy/compose.yml
    lib/paths.sh
    lib/compose.sh
    services/registry.sh
    services/mqtt/compose.yml
    services/uptime-kuma/compose.yml
    install/provisioning/systemd/lisa-first-boot.service
  )
  for file in "${copies[@]}"; do
    mkdir -p "$FAKE_REPO/$(dirname "$file")"
    cp "$RESET_REPO_ROOT/$file" "$FAKE_REPO/$file"
  done
  chmod +x "$FAKE_REPO/lisa-edge" "$FAKE_REPO/ops/deploy/reset-node.sh"

  mkdir -p "$FAKE_REPO/install/bootstrap/phases" \
    "$FAKE_REPO/install/provisioning" \
    "$FAKE_REPO/rescue/scripts"

  cat > "$FAKE_REPO/ops/deploy/deploy.sh" <<'STUB'
#!/usr/bin/env bash
echo "deploy.sh $*" >> "$RESET_TEST_LOG"
exit "${RESET_TEST_DEPLOY_RC:-0}"
STUB

  cat > "$FAKE_REPO/install/bootstrap/phases/30-directories.sh" <<'STUB'
#!/usr/bin/env bash
echo "30-directories.sh" >> "$RESET_TEST_LOG"
# Guardrail for the test harness itself: a hostile fixture value must never
# leak a real directory onto the machine running the tests.
case "${DATA_ROOT:-}" in
  /tmp/*) mkdir -p "$DATA_ROOT"/{backups,data,docker,logs,state,secrets} ;;
  *) echo "HARNESS ESCAPE: refusing non-/tmp DATA_ROOT: ${DATA_ROOT:-}" >&2; exit 1 ;;
esac
STUB

  cat > "$FAKE_REPO/install/provisioning/notify-first-boot.sh" <<'STUB'
#!/usr/bin/env bash
echo "notify-first-boot.sh" >> "$RESET_TEST_LOG"
STUB

  cat > "$FAKE_REPO/rescue/scripts/reinstall-guide.sh" <<'STUB'
#!/usr/bin/env bash
echo "repo-reinstall-guide.sh" >> "$RESET_TEST_LOG"
echo "LISA Edge Production Reinstall Guide (repo copy)"
STUB

  chmod +x "$FAKE_REPO/ops/deploy/deploy.sh" \
    "$FAKE_REPO/install/bootstrap/phases/30-directories.sh" \
    "$FAKE_REPO/install/provisioning/notify-first-boot.sh" \
    "$FAKE_REPO/rescue/scripts/reinstall-guide.sh"
}

reset_harness_build_stubs() {
  cat > "$BIN/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker $*" >> "$RESET_TEST_LOG"
case "$1" in
  ps)
    shift
    if [ "$*" = "-q" ]; then
      exit 0
    fi
    if [ -f "$RESET_TEST_STATE/leftover-container" ] &&
       [ ! -f "$RESET_TEST_STATE/removed-container" ]; then
      echo cid123
    fi
    exit 0
    ;;
  compose)
    case "$*" in
      *" config") echo "name: ${RESET_TEST_PROJECT:-lisa-edge}" ;;
    esac
    exit 0
    ;;
  network)
    case "$2" in
      ls)
        if [ -f "$RESET_TEST_STATE/leftover-network" ] &&
           [ ! -f "$RESET_TEST_STATE/removed-network" ]; then
          echo netid1
        fi
        ;;
      rm) touch "$RESET_TEST_STATE/removed-network" ;;
    esac
    exit 0
    ;;
  volume)
    case "$2" in
      ls)
        if [ -f "$RESET_TEST_STATE/leftover-volume" ] &&
           [ ! -f "$RESET_TEST_STATE/removed-volume" ]; then
          echo volid1
        fi
        ;;
      rm) touch "$RESET_TEST_STATE/removed-volume" ;;
    esac
    exit 0
    ;;
  rm)
    touch "$RESET_TEST_STATE/removed-container"
    exit 0
    ;;
esac
exit 0
STUB

  cat > "$BIN/systemctl" <<'STUB'
#!/usr/bin/env bash
echo "systemctl $*" >> "$RESET_TEST_LOG"
case "$1" in
  is-active) exit "${RESET_TEST_TIMER_ACTIVE_RC:-0}" ;;
  stop) exit "${RESET_TEST_SYSTEMCTL_STOP_RC:-0}" ;;
esac
exit 0
STUB

  cat > "$BIN/findmnt" <<'STUB'
#!/usr/bin/env bash
echo "findmnt $*" >> "$RESET_TEST_LOG"
if [ "${RESET_TEST_FINDMNT_FAIL:-0}" = "1" ]; then
  exit 1
fi
cat "$RESET_TEST_FINDMNT_TABLE"
STUB

  chmod +x "$BIN/docker" "$BIN/systemctl" "$BIN/findmnt"
}

# Seed a provisioned-host fixture: .env, runtime data, local backups,
# installed production units, provision marker and CLI symlinks. The
# Rescue Layer diagnostic units are seeded too, to prove they stay
# untouched.
reset_harness_seed_provisioned_host() {
  local backup_dest="${1:-$DATAROOT/backups}"

  cat > "$FAKE_REPO/.env" <<ENV
DATA_ROOT='$DATAROOT'
BACKUP_DEST='$backup_dest'
COMPOSE_PROJECT_NAME='lisa-edge'
LISA_COMPOSE_SERVICES='mqtt uptime-kuma'
ENV
  cp "$FAKE_REPO/.env" "$FAKE_REPO/.env.before-wizard-20260101-000000"
  printf 'tmp\n' > "$FAKE_REPO/.env.tmp"

  mkdir -p \
    "$DATAROOT/data/tailscale" \
    "$DATAROOT/docker/volumes/matter-server" \
    "$DATAROOT/docker/volumes/mosquitto/config" \
    "$DATAROOT/docker/volumes/otbr" \
    "$DATAROOT/state" \
    "$DATAROOT/logs" \
    "$DATAROOT/secrets" \
    "$DATAROOT/backups/otbr"
  printf 'ts-state\n' > "$DATAROOT/data/tailscale/tailscaled.state"
  printf 'fabric\n' > "$DATAROOT/docker/volumes/matter-server/fabric.json"
  printf 'passwords\n' > "$DATAROOT/docker/volumes/mosquitto/config/passwords"
  printf 'otbr-live\n' > "$DATAROOT/docker/volumes/otbr/settings.dat"
  printf 'state\n' > "$DATAROOT/state/marker"
  printf 'log\n' > "$DATAROOT/logs/service.log"
  printf 'secret\n' > "$DATAROOT/secrets/generated.token"
  printf 'archive\n' > "$DATAROOT/backups/lisa-edge-backup-1.tar.gz"
  printf 'dataset\n' > "$DATAROOT/backups/otbr/latest.dataset.hex"
  printf 'external\n' > "$EXTERNAL_BACKUPS/lisa-edge-backup-external.tar.gz"

  local unit
  for unit in \
    lisa-edge.service \
    lisa-edge-backup.service lisa-edge-backup.timer \
    lisa-otbr-dataset-backup.service lisa-otbr-dataset-backup.timer \
    lisa-matter-data-backup.service lisa-matter-data-backup.timer \
    lisa-rescue-diagnostics.service lisa-rescue-diagnostics.timer; do
    printf '[Unit]\nDescription=%s fixture\n' "$unit" > "$SYSTEMD_DIR/$unit"
  done

  printf 'provisioned\n' > "$STATE_DIR/provisioned"
  ln -sfn "$FAKE_REPO/lisa-edge" "$SBIN_DIR/lisa-edge"
  ln -sfn "$FAKE_REPO/lisa-edge" "$SBIN_DIR/lisa-edge-provision"
}

# Run the reset CLI inside the harness. Usage:
#   run_reset [--stdin TEXT] [--env NAME=VALUE]... -- <cli arguments>...
# Captures OUTPUT (stdout+stderr) and RC.
run_reset() {
  local stdin_text=""
  local extra_env=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --stdin) stdin_text="$2"; shift 2 ;;
      --env) extra_env+=("$2"); shift 2 ;;
      --) shift; break ;;
      *) break ;;
    esac
  done

  RC=0
  OUTPUT="$(
    printf '%s\n' "$stdin_text" |
      env \
        PATH="$BIN:$PATH" \
        LISA_EDGE_TESTING=1 \
        LISA_RESET_SYSTEMD_DIR="$SYSTEMD_DIR" \
        LISA_RESET_STATE_DIR="$STATE_DIR" \
        LISA_RESET_SBIN_DIR="$SBIN_DIR" \
        LISA_RESET_RESCUE_ROOT="$RESCUE_ROOT" \
        RESET_TEST_LOG="$LOG" \
        RESET_TEST_STATE="$STATE" \
        RESET_TEST_FINDMNT_TABLE="$FINDMNT_TABLE" \
        "${extra_env[@]}" \
        bash "$FAKE_REPO/lisa-edge" reset "$@" 2>&1
  )" || RC=$?
}

log_contains() {
  grep -Fq -- "$1" "$LOG"
}

log_lacks() {
  ! grep -Fq -- "$1" "$LOG"
}

output_contains() {
  grep -Fq -- "$1" <<< "$OUTPUT"
}
