#!/usr/bin/env bash
# Build a complete LISA Edge installer USB in one pass (Linux):
#
#   1. fetch   platform/linux/fetch-ubuntu-iso.sh   (download + verify ISO)
#   2. write   platform/linux/create-usb-disk.sh    (bootable FAT32 USB, replaces Rufus)
#   3. inject  ../prepare/prepare-<profile>-usb.sh  (autoinstall user-data/meta-data/grub.cfg)
#
# The result boots UEFI systems only (ZimaBoard 2, NUC, modern mini PCs).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLATFORM_DIR="$SCRIPT_DIR/platform/linux"
PREPARE_DIR="$(cd "$SCRIPT_DIR/../prepare" && pwd -P)"

PROFILE=""
DEVICE=""
ISO_PATH=""
RELEASE=""
ASSUME_YES=0
DRY_RUN=0
KEEP_MOUNTED=0

log() { printf '%s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    cat >&2 <<EOF
Usage:
  sudo $(basename "$0") <production|rescue> --device /dev/sdX [options]

Steps: download + verify the Ubuntu Server ISO, write a bootable UEFI USB
(no Rufus needed), then inject the LISA Edge autoinstall profile.

Options:
      --device <dev>     Target USB block device (whole disk, e.g. /dev/sdb).
      --iso <path>       Use an already-downloaded ISO (skips the fetch step).
      --release <series> Release series from config/ubuntu-releases.json.
  -y, --yes              Non-interactive: skip confirmations.
      --dry-run          Validate everything, change nothing.
      --keep-mounted     Leave the USB mounted after finishing.
  -h, --help             Show this help.

Identify the correct device first:
  lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TYPE,TRAN,RM,MOUNTPOINTS
EOF
}

parse_args() {
    [[ $# -ge 1 ]] || { usage; exit 1; }
    case "$1" in
        production|rescue) PROFILE="$1"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage; die "first argument must be 'production' or 'rescue'" ;;
    esac
    while (( $# > 0 )); do
        case "$1" in
            --device)  [[ -n "${2:-}" ]] || die "missing value for $1"; DEVICE="$2"; shift 2 ;;
            --iso)     [[ -n "${2:-}" ]] || die "missing value for $1"; ISO_PATH="$2"; shift 2 ;;
            --release) [[ -n "${2:-}" ]] || die "missing value for $1"; RELEASE="$2"; shift 2 ;;
            -y|--yes)  ASSUME_YES=1; shift ;;
            --dry-run) DRY_RUN=1; shift ;;
            --keep-mounted) KEEP_MOUNTED=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *)         usage; die "unknown argument: $1" ;;
        esac
    done
    [[ -n "$DEVICE" ]] || die "--device is required (never guessed); see lsblk hint in --help"
}

main() {
    parse_args "$@"

    local prepare_script="$PREPARE_DIR/prepare-${PROFILE}-usb.sh"
    [[ -f "$prepare_script" ]] || die "missing prepare script: $prepare_script"

    # Step 1/3: obtain a verified ISO.
    if [[ -z "$ISO_PATH" ]]; then
        log ""
        log "==> [1/3] Downloading and verifying the Ubuntu Server ISO"
        local fetch_args=()
        [[ -n "$RELEASE" ]] && fetch_args+=(--release "$RELEASE")
        ISO_PATH="$(bash "$PLATFORM_DIR/fetch-ubuntu-iso.sh" "${fetch_args[@]}" | tail -n 1)"
        [[ -n "$ISO_PATH" && -f "$ISO_PATH" ]] || die "ISO fetch did not produce a usable file"
    else
        log "==> [1/3] Using provided ISO: $ISO_PATH (fetch skipped)"
        [[ -f "$ISO_PATH" ]] || die "ISO not found: $ISO_PATH"
    fi

    # Step 2/3: write the bootable USB.
    log ""
    log "==> [2/3] Writing the bootable installer USB ($DEVICE)"
    local create_args=(--device "$DEVICE" --iso "$ISO_PATH")
    (( ASSUME_YES )) && create_args+=(--yes)
    (( DRY_RUN )) && create_args+=(--dry-run)
    local usb_mount=""
    usb_mount="$(bash "$PLATFORM_DIR/create-usb-disk.sh" "${create_args[@]}" | tail -n 1)"

    if (( DRY_RUN )); then
        log ""
        log "==> [3/3] Skipped (dry-run): would inject the '$PROFILE' autoinstall profile"
        log "Dry-run finished; no changes were made."
        return 0
    fi
    [[ -n "$usb_mount" && -d "$usb_mount" ]] || die "USB creation did not report a mount point"

    # Step 3/3: inject the autoinstall profile.
    log ""
    log "==> [3/3] Injecting the LISA Edge '$PROFILE' autoinstall profile"
    local prepare_args=()
    if [[ "$PROFILE" == "production" ]]; then
        (( ASSUME_YES )) && prepare_args+=(--yes)
    fi
    bash "$prepare_script" "${prepare_args[@]}" "$usb_mount"

    sync
    if (( KEEP_MOUNTED )); then
        log ""
        log "Done. USB is still mounted at: $usb_mount"
    else
        umount "$usb_mount" || die "could not unmount $usb_mount; unmount it manually before removing the USB"
        rmdir "$usb_mount" 2>/dev/null || true
        log ""
        log "Done. USB unmounted; it is safe to remove."
    fi
    log "Boot the target machine from this USB (UEFI) and confirm the installer targets the correct disk."
}

main "$@"
