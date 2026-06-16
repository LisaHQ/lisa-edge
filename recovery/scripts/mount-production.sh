#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
MOUNTPOINT="${2:-/mnt/lisa-production}"

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

mkdir -p "$MOUNTPOINT"

echo "[INFO] Mounting $TARGET to $MOUNTPOINT"
mount "$TARGET" "$MOUNTPOINT"

for dir in dev proc sys run; do
    if [[ -d "$MOUNTPOINT/$dir" ]]; then
        mount --bind "/$dir" "$MOUNTPOINT/$dir"
    fi
done

echo "[INFO] Production root mounted at $MOUNTPOINT"
echo "[INFO] To chroot:"
echo "  sudo chroot $MOUNTPOINT /bin/bash"
echo
echo "[INFO] To unmount later:"
echo "  sudo umount -R $MOUNTPOINT"
