#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
MOUNTPOINT="${2:-/mnt/lisa-production}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/recovery-safety.sh"

if [[ -z "$TARGET" ]]; then
    echo "Usage: sudo $0 <production-root-partition> [mountpoint]"
    echo
    echo "Example:"
    echo "  sudo $0 /dev/sda2"
    echo
    lsblk -o NAME,PATH,SIZE,FSTYPE,MODEL,SERIAL,TYPE,MOUNTPOINTS
    exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

MOUNTPOINT="$(recovery_validate_mount_path "$MOUNTPOINT")"
TARGET="$(readlink -f -- "$TARGET")"
if [[ ! -b "$TARGET" ]]; then
    echo "ERROR: Target is not a block device: $TARGET"
    exit 1
fi
if findmnt -rn -S "$TARGET" >/dev/null 2>&1; then
    echo "ERROR: Target is already mounted: $TARGET"
    findmnt -rn -S "$TARGET"
    exit 1
fi

mkdir -p "$MOUNTPOINT"
if find "$MOUNTPOINT" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    echo "ERROR: Mountpoint is not empty: $MOUNTPOINT"
    exit 1
fi

echo "[INFO] Mounting $TARGET to $MOUNTPOINT"
MOUNTED=0
cleanup_failed_mount() {
    local status=$?
    if [[ "$MOUNTED" -eq 1 ]]; then
        echo "[WARN] Mount preparation failed; unmounting $MOUNTPOINT" >&2
        umount -R "$MOUNTPOINT" >/dev/null 2>&1 || true
    fi
    exit "$status"
}
trap cleanup_failed_mount ERR
mount "$TARGET" "$MOUNTPOINT"
MOUNTED=1
recovery_require_exact_mount "$MOUNTPOINT"

for dir in dev proc sys run; do
    if [[ -d "$MOUNTPOINT/$dir" ]]; then
        mount --bind "/$dir" "$MOUNTPOINT/$dir"
    fi
done
trap - ERR

echo "[INFO] Production root mounted at $MOUNTPOINT"
echo "[INFO] To chroot:"
echo "  sudo chroot $MOUNTPOINT /bin/bash"
echo
echo "[INFO] To unmount later:"
echo "  sudo umount -R $MOUNTPOINT"
