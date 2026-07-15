#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/recovery-safety.sh"

SNAPSHOT_SOURCE="${SNAPSHOT_SOURCE:-${BACKUP_SOURCE:-}}"
PRODUCTION_ROOT="${PRODUCTION_ROOT:-/mnt/lisa-production}"

if [[ -z "$SNAPSHOT_SOURCE" ]]; then
    cat <<'EOF'
ERROR: SNAPSHOT_SOURCE is not set.

Example:

  export SNAPSHOT_SOURCE=/mnt/lisa-backup/filesystem-snapshot/
  export PRODUCTION_ROOT=/mnt/lisa-production
  sudo -E /opt/lisa-rescue/scripts/restore-filesystem-snapshot.sh

This command copies a trusted directory snapshot over the mounted production
filesystem. For a lisa-edge-backup-*.tar.gz archive, use
restore-edge-backup.sh instead.
EOF
    exit 1
fi

if [[ ! -d "$SNAPSHOT_SOURCE" ]]; then
    echo "ERROR: SNAPSHOT_SOURCE does not exist: $SNAPSHOT_SOURCE"
    exit 1
fi
if [[ ! -d "$PRODUCTION_ROOT" ]]; then
    echo "ERROR: PRODUCTION_ROOT does not exist: $PRODUCTION_ROOT"
    echo "Mount production root first, for example:"
    echo "  sudo /opt/lisa-rescue/scripts/mount-production.sh /dev/sdX2"
    exit 1
fi

SNAPSHOT_SOURCE="$(readlink -f -- "$SNAPSHOT_SOURCE")"
PRODUCTION_ROOT="$(recovery_validate_mount_path "$PRODUCTION_ROOT")"
recovery_require_exact_mount "$PRODUCTION_ROOT"
recovery_refuse_overlapping_paths "$SNAPSHOT_SOURCE" "$PRODUCTION_ROOT"

echo "[INFO] Filesystem snapshot restore"
echo "  source: $SNAPSHOT_SOURCE"
echo "  target: $PRODUCTION_ROOT"
echo "[INFO] Mounted filesystem:"
findmnt -rn -M "$PRODUCTION_ROOT" -o SOURCE,TARGET,FSTYPE,SIZE,AVAIL
echo

read -r -p "Type RESTORE to continue: " CONFIRM
if [[ "$CONFIRM" != "RESTORE" ]]; then
    echo "Aborted."
    exit 1
fi

# mount-production.sh bind-mounts the live /dev, /proc, /sys and /run into
# the target for chroot workflows. Never rsync snapshot content into those:
# it would write into the RUNNING rescue OS instead of the production disk.
rsync -aHAX --numeric-ids --info=progress2 \
    --exclude=/dev/* \
    --exclude=/proc/* \
    --exclude=/sys/* \
    --exclude=/run/* \
    --exclude=/tmp/* \
    "$SNAPSHOT_SOURCE"/ \
    "$PRODUCTION_ROOT"/

echo "[INFO] Filesystem snapshot restore completed."
