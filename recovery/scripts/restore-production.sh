#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/recovery-safety.sh"

BACKUP_SOURCE="${BACKUP_SOURCE:-}"
PRODUCTION_ROOT="${PRODUCTION_ROOT:-/mnt/lisa-production}"

if [[ -z "$BACKUP_SOURCE" ]]; then
    cat <<'EOF'
ERROR: BACKUP_SOURCE is not set.

Example:

  export BACKUP_SOURCE=/mnt/backup/lisa-edge/latest/
  export PRODUCTION_ROOT=/mnt/lisa-production
  sudo -E /opt/lisa-rescue/scripts/restore-production.sh

This script intentionally requires BACKUP_SOURCE to avoid accidental restores.
EOF
    exit 1
fi

if [[ ! -d "$BACKUP_SOURCE" ]]; then
    echo "ERROR: BACKUP_SOURCE does not exist: $BACKUP_SOURCE"
    exit 1
fi

if [[ ! -d "$PRODUCTION_ROOT" ]]; then
    echo "ERROR: PRODUCTION_ROOT does not exist: $PRODUCTION_ROOT"
    echo "Mount production root first, for example:"
    echo "  sudo /opt/lisa-rescue/scripts/mount-production.sh /dev/sdX2"
    exit 1
fi

BACKUP_SOURCE="$(readlink -f -- "$BACKUP_SOURCE")"
PRODUCTION_ROOT="$(recovery_validate_mount_path "$PRODUCTION_ROOT")"
recovery_require_exact_mount "$PRODUCTION_ROOT"
recovery_refuse_overlapping_paths "$BACKUP_SOURCE" "$PRODUCTION_ROOT"

echo "[INFO] Restoring from:"
echo "  $BACKUP_SOURCE"
echo "[INFO] Restoring to:"
echo "  $PRODUCTION_ROOT"
echo "[INFO] Mounted filesystem:"
findmnt -rn -M "$PRODUCTION_ROOT" -o SOURCE,TARGET,FSTYPE,SIZE,AVAIL
echo

read -r -p "Type RESTORE to continue: " CONFIRM
if [[ "$CONFIRM" != "RESTORE" ]]; then
    echo "Aborted."
    exit 1
fi

rsync -aHAX --numeric-ids --info=progress2 \
    "$BACKUP_SOURCE"/ \
    "$PRODUCTION_ROOT"/

echo "[INFO] Restore completed."
