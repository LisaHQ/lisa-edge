#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: sudo $0 [--yes] [--mount /media/user/UBUNTU_USB]

This script detects a mounted Ubuntu Server USB and copies cloud-init autoinstall files to /server on that USB.
It does not write an ISO image. Create the Ubuntu Server USB first, then run this script.
USAGE
}

YES=0
MOUNT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) YES=1 ;;
    --mount) MOUNT="${2:-}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_DIR="$REPO_DIR/usb-installer/production/autoinstall"

if [ -z "$MOUNT" ]; then
  mapfile -t CANDIDATES < <(findmnt -rn -o TARGET,SOURCE,FSTYPE,LABEL | awk 'BEGIN{IGNORECASE=1} /ubuntu|jammy|noble|server|cidata|usb/ {print $1}' | sort -u)
  if [ "${#CANDIDATES[@]}" -eq 0 ]; then
    echo "Could not auto-detect Ubuntu USB mount. Run: lsblk -f, then pass --mount /path/to/usb" >&2
    exit 1
  fi
  if [ "${#CANDIDATES[@]}" -gt 1 ]; then
    echo "Multiple possible USB mounts found:" >&2
    printf '  %s\n' "${CANDIDATES[@]}" >&2
    echo "Re-run with --mount /path/to/usb" >&2
    exit 1
  fi
  MOUNT="${CANDIDATES[0]}"
fi

if [ ! -d "$MOUNT" ]; then
  echo "Mount path does not exist: $MOUNT" >&2
  exit 1
fi

if [ ! -f "$SRC_DIR/user-data" ] || [ ! -f "$SRC_DIR/meta-data" ]; then
  echo "Missing source autoinstall files in: $SRC_DIR" >&2
  exit 1
fi

echo "USB mount: $MOUNT"
echo "Files will be copied to: $MOUNT/autoinstall"
if [ "$YES" -ne 1 ]; then
  read -r -p "Continue? Type YES: " answer
  [ "$answer" = "YES" ] || { echo "Aborted."; exit 1; }
fi

mkdir -p "$MOUNT/autoinstall"
cp "$SRC_DIR/user-data" "$MOUNT/autoinstall/user-data"
cp "$SRC_DIR/meta-data" "$MOUNT/autoinstall/meta-data"

# grub.cfg location varies by ISO layout. Patch common paths when present.
for grub in "$MOUNT/boot/grub/grub.cfg" "$MOUNT/EFI/BOOT/grub.cfg" "$MOUNT/grub/grub.cfg"; do
  if [ -f "$grub" ]; then
    cp "$grub" "$grub.bak.$(date +%Y%m%d-%H%M%S)"
    if ! grep -q 'autoinstall ds=nocloud;s=/cdrom/server/' "$grub"; then
      sed -i -E 's#(linux[[:space:]]+/casper/vmlinuz[^\r\n]*)#\1 autoinstall ds=nocloud\;s=/cdrom/server/#' "$grub"
    fi
    echo "Patched: $grub"
  fi
done

sync
echo "Done. Safely eject the USB before unplugging it."
