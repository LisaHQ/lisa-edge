#!/usr/bin/env bash
# Create a bootable Ubuntu installer USB from a verified ISO (replaces Rufus).
#
# Approach (UEFI-only, matches what Rufus "ISO mode" does):
#   GPT + one FAT32 partition + full ISO contents copied onto it.
# The USB stays writable so the autoinstall prepare scripts can inject
# user-data / meta-data / grub.cfg afterwards.
#
# DESTRUCTIVE: erases the selected device. Validation is fail-closed:
#   - the target must be a whole, removable, USB-class block device
#   - devices with mounted filesystems are rejected
#   - the device is never guessed; --device is mandatory
#   - confirmation requires typing the device name unless --yes
#
# Prints the mount point of the prepared USB as the LAST line on stdout.
# Diagnostics go to stderr.

set -euo pipefail

# Overridable for tests only. Tests never touch real devices.
SYS_BLOCK_DIR="${LISA_TEST_SYS_BLOCK_DIR:-/sys/block}"
PROC_MOUNTS="${LISA_TEST_PROC_MOUNTS:-/proc/mounts}"

FAT32_MAX_PART_BYTES=$((32 * 1024 * 1024 * 1024))   # parity with Windows format limit
FAT32_MAX_FILE_BYTES=$((4 * 1024 * 1024 * 1024 - 1))
MIN_DEVICE_BYTES=$((4 * 1024 * 1024 * 1024))

DEVICE=""
ISO_PATH=""
LABEL="LISA-USB"
MOUNT_POINT=""
ASSUME_YES=0
DRY_RUN=0

log() { printf '%s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    cat >&2 <<EOF
Usage:
  sudo $(basename "$0") --device /dev/sdX --iso /path/to/ubuntu.iso [options]

Options:
      --device <dev>       Target USB block device (whole disk, e.g. /dev/sdb).
      --iso <path>         Verified Ubuntu ISO (see fetch-ubuntu-iso.sh).
      --label <name>       FAT32 volume label (default: LISA-USB).
      --mount-point <dir>  Where to leave the USB mounted (default: mktemp -d).
  -y, --yes                Skip the interactive confirmation.
      --dry-run            Validate everything, change nothing.
  -h, --help               Show this help.

Identify the correct device first:
  lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TYPE,TRAN,RM,MOUNTPOINTS
EOF
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --device)      [[ -n "${2:-}" ]] || die "missing value for $1"; DEVICE="$2"; shift 2 ;;
            --iso)         [[ -n "${2:-}" ]] || die "missing value for $1"; ISO_PATH="$2"; shift 2 ;;
            --label)       [[ -n "${2:-}" ]] || die "missing value for $1"; LABEL="$2"; shift 2 ;;
            --mount-point) [[ -n "${2:-}" ]] || die "missing value for $1"; MOUNT_POINT="$2"; shift 2 ;;
            -y|--yes)      ASSUME_YES=1; shift ;;
            --dry-run)     DRY_RUN=1; shift ;;
            -h|--help)     usage; exit 0 ;;
            *)             usage; die "unknown argument: $1" ;;
        esac
    done
}

require_tools() {
    local tool
    for tool in lsblk wipefs parted mkfs.vfat mount umount blockdev; do
        command -v "$tool" >/dev/null || die "required tool missing: $tool (Debian/Ubuntu: apt install util-linux parted dosfstools mount)"
    done
}

# --- validation helpers (pure checks; sourceable by tests) -------------------

# validate_device_path <device> -> 0 or dies
validate_device_path() {
    local device="$1"
    [[ -n "$device" ]] || die "--device is required (never guessed)"
    [[ "$device" == /dev/* ]] || die "device must be an absolute /dev path: $device"
    [[ "$device" != *" "* && "$device" != *".."* ]] || die "unsafe device path: $device"
    [[ -b "$device" ]] || die "not a block device: $device"
}

# validate_whole_disk <device> : reject partitions; whole disks appear in /sys/block
validate_whole_disk() {
    local device="$1" name
    name="$(basename "$device")"
    [[ -d "$SYS_BLOCK_DIR/$name" ]] ||
        die "$device is not a whole disk (partitions like ${device}1 are not accepted)"
}

# validate_removable <device> : /sys/block/<name>/removable must be 1
validate_removable() {
    local device="$1" name flag
    name="$(basename "$device")"
    flag="$(cat "$SYS_BLOCK_DIR/$name/removable" 2>/dev/null || echo 0)"
    [[ "$flag" == "1" ]] ||
        die "$device is not a removable device; refusing to erase it (fail closed)"
}

# validate_not_mounted <device> : no mount entry may use the disk or its partitions
validate_not_mounted() {
    local device="$1" src mnt rest
    while read -r src mnt rest; do
        if [[ "$src" == "$device" || "$src" == "$device"[0-9]* || "$src" == "${device}p"[0-9]* ]]; then
            die "$device has a mounted filesystem at $mnt; unmount it first"
        fi
    done < "$PROC_MOUNTS"
}

# validate_device_size <device> <iso-path>
validate_device_size() {
    local device="$1" iso="$2" dev_bytes iso_bytes
    dev_bytes="$(blockdev --getsize64 "$device")"
    iso_bytes="$(stat -c %s "$iso")"
    (( dev_bytes >= MIN_DEVICE_BYTES )) ||
        die "$device is smaller than 4 GiB; too small for an Ubuntu installer"
    (( dev_bytes >= iso_bytes + 256 * 1024 * 1024 )) ||
        die "$device ($dev_bytes bytes) is too small for the ISO ($iso_bytes bytes)"
}

# validate_iso_contents <mounted-iso-dir> : UEFI boot files + FAT32 file-size guard
validate_iso_contents() {
    local iso_root="$1" oversized
    [[ -d "$iso_root/casper" ]] || die "ISO does not look like an Ubuntu live installer (missing casper/)"
    [[ -e "$iso_root/EFI/boot/bootx64.efi" || -e "$iso_root/efi/boot/bootx64.efi" ]] ||
        die "ISO has no UEFI bootloader (EFI/boot/bootx64.efi); this pipeline is UEFI-only"
    oversized="$(find "$iso_root" -type f -size +${FAT32_MAX_FILE_BYTES}c -print -quit)"
    [[ -z "$oversized" ]] ||
        die "ISO contains a file larger than 4 GiB, which FAT32 cannot store: $oversized"
}

# -----------------------------------------------------------------------------

# copy_iso_contents <src> <dst> : copy everything except symlinks (FAT32
# cannot store them; the Ubuntu ISO ships a decorative "ubuntu -> ." link).
copy_iso_contents() {
    local src="$1" dst="$2"
    (cd "$src" && find . ! -type l -print0 |
        tar --null --no-recursion -T - -cf -) |
        tar -C "$dst" -xf - --no-same-owner --no-same-permissions ||
        die "copying installer files to the USB failed"
}

confirm_or_die() {
    local device="$1"
    log ""
    log "About to ERASE ALL DATA on:"
    lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN,RM "$device" >&2 || true
    log ""
    if (( ASSUME_YES )); then
        log "--yes given; skipping confirmation."
        return 0
    fi
    [[ -t 0 ]] || die "stdin is not a terminal; use --yes for non-interactive runs"
    local answer=""
    read -r -p "Type the device path ($device) to continue: " answer
    [[ "$answer" == "$device" ]] || die "confirmation did not match; aborting with no changes"
}

partition_suffix() {
    # nvme0n1 -> p1 ; sdb -> 1
    local device="$1"
    [[ "$device" =~ [0-9]$ ]] && printf 'p1' || printf '1'
}

main() {
    parse_args "$@"
    require_tools

    [[ -n "$ISO_PATH" ]] || die "--iso is required"
    [[ -f "$ISO_PATH" ]] || die "ISO not found: $ISO_PATH"

    validate_device_path "$DEVICE"
    validate_whole_disk "$DEVICE"
    validate_removable "$DEVICE"
    validate_not_mounted "$DEVICE"
    validate_device_size "$DEVICE" "$ISO_PATH"

    if (( ! DRY_RUN )); then
        [[ "$(id -u)" == "0" ]] || die "must run as root (sudo) to partition and mount"
    fi

    # Inspect the ISO before touching the device (loop mount, read-only).
    local iso_mnt
    iso_mnt="$(mktemp -d /tmp/lisa-iso.XXXXXX)"
    local usb_mnt=""
    cleanup() {
        mountpoint -q "$iso_mnt" 2>/dev/null && umount "$iso_mnt"
        rmdir "$iso_mnt" 2>/dev/null || true
        if [[ -n "$usb_mnt" ]] && mountpoint -q "$usb_mnt" 2>/dev/null; then
            umount "$usb_mnt" || true
        fi
    }
    trap cleanup EXIT

    if (( DRY_RUN )) && [[ "$(id -u)" != "0" ]]; then
        log "[dry-run] skipping ISO content inspection (needs root for loop mount)"
    else
        mount -o loop,ro "$ISO_PATH" "$iso_mnt" || die "cannot loop-mount ISO: $ISO_PATH"
        validate_iso_contents "$iso_mnt"
    fi

    local part_bytes dev_bytes
    dev_bytes="$(blockdev --getsize64 "$DEVICE")"
    part_bytes=$(( dev_bytes < FAT32_MAX_PART_BYTES ? dev_bytes : FAT32_MAX_PART_BYTES ))

    if (( DRY_RUN )); then
        log "[dry-run] validation passed for $DEVICE"
        log "[dry-run] would create: GPT + FAT32 partition ($(( part_bytes / 1024 / 1024 )) MiB, label $LABEL)"
        log "[dry-run] would copy ISO contents from $ISO_PATH"
        log "[dry-run] no changes were made"
        return 0
    fi

    confirm_or_die "$DEVICE"

    local part="${DEVICE}$(partition_suffix "$DEVICE")"
    local part_end_mib=$(( part_bytes / 1024 / 1024 - 1 ))

    log "Wiping filesystem signatures on $DEVICE..."
    wipefs -a "$DEVICE" >&2

    log "Creating GPT + FAT32 partition..."
    parted -s "$DEVICE" mklabel gpt >&2
    parted -s "$DEVICE" mkpart LISAUSB fat32 4MiB "${part_end_mib}MiB" >&2
    parted -s "$DEVICE" set 1 esp on >&2
    command -v udevadm >/dev/null && udevadm settle >&2 || sleep 2
    [[ -b "$part" ]] || { sleep 2; [[ -b "$part" ]] || die "partition did not appear: $part"; }

    log "Formatting $part as FAT32 (label: $LABEL)..."
    mkfs.vfat -F 32 -n "$LABEL" "$part" >&2

    if [[ -z "$MOUNT_POINT" ]]; then
        usb_mnt="$(mktemp -d /mnt/lisa-usb.XXXXXX 2>/dev/null || mktemp -d /tmp/lisa-usb.XXXXXX)"
    else
        mkdir -p "$MOUNT_POINT"
        usb_mnt="$MOUNT_POINT"
    fi
    mount "$part" "$usb_mnt"

    log "Copying installer files (this can take a few minutes)..."
    copy_iso_contents "$iso_mnt" "$usb_mnt"

    log "Flushing writes to $DEVICE..."
    sync

    # Verify anchors on the USB itself.
    [[ -d "$usb_mnt/casper" ]] || die "copy verification failed: casper/ missing on USB"
    [[ -e "$usb_mnt/EFI/boot/bootx64.efi" || -e "$usb_mnt/efi/boot/bootx64.efi" ]] ||
        die "copy verification failed: UEFI bootloader missing on USB"
    [[ -e "$usb_mnt/boot/grub/grub.cfg" ]] || die "copy verification failed: boot/grub/grub.cfg missing on USB"

    umount "$iso_mnt"; rmdir "$iso_mnt" 2>/dev/null || true
    trap - EXIT

    log "Bootable Ubuntu USB ready (UEFI) and mounted."
    printf '%s\n' "$usb_mnt"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
