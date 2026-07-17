#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOINSTALL_DIR="$(cd "$SCRIPT_DIR/../../config/rescue" && pwd -P)"

usage() {
    cat <<'EOF'
Usage:
  sudo bash install/usb/scripts/prepare/prepare-rescue-usb.sh <usb-mount-path>

Example:
  sudo bash install/usb/scripts/prepare/prepare-rescue-usb.sh /media/$USER/UBUNTU_USB

This script prepares an Ubuntu Server USB for automatic Rescue OS installation.

It copies:
  config/rescue/meta-data
  config/rescue/user-data
  config/rescue/grub.cfg

to the USB drive.

The USB should already contain Ubuntu Server installer files.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

require_file() {
    local file="$1"
    [[ -f "$file" ]] || die "missing required file: $file"
}

copy_user_data() {
    local build_dir="$1"
    local source_user_data="$AUTOINSTALL_DIR/user-data"
    local template_user_data="$AUTOINSTALL_DIR/user-data.template"

    if [[ -f "$source_user_data" ]]; then
        cp "$source_user_data" "$build_dir/user-data"
    elif [[ -f "$template_user_data" ]]; then
        cp "$template_user_data" "$build_dir/user-data"
    else
        die "missing user-data or user-data.template in $AUTOINSTALL_DIR"
    fi

    if grep -Eq "REPLACE_WITH_|YOUR_|CHANGEME" "$build_dir/user-data"; then
        cat >&2 <<'EOF'
ERROR: rescue user-data still contains placeholder values.

Edit one of these files first:
  install/usb/config/rescue/user-data
  install/usb/config/rescue/user-data.template

Required values usually include:
  - eMMC serial
  - SSH public key
  - password hash
EOF
        exit 1
    fi
}

main() {
    local usb_mount="${1:-}"

    if [[ -z "$usb_mount" || "$usb_mount" == "-h" || "$usb_mount" == "--help" ]]; then
        usage
        exit 0
    fi

    [[ -d "$usb_mount" ]] || die "USB mount path does not exist: $usb_mount"
    [[ -w "$usb_mount" ]] || die "USB mount path is not writable: $usb_mount"

    require_file "$AUTOINSTALL_DIR/meta-data"
    require_file "$AUTOINSTALL_DIR/grub.cfg"

    if [[ ! -d "$usb_mount/casper" ]]; then
        die "USB does not look like an Ubuntu Server installer. Missing: $usb_mount/casper"
    fi

    local target_autoinstall="$usb_mount/autoinstall"
    local temp_dir
    temp_dir="$(mktemp -d)"

    cleanup() {
        rm -rf "$temp_dir"
    }
    trap cleanup EXIT

    mkdir -p "$temp_dir/autoinstall"
    cp "$AUTOINSTALL_DIR/meta-data" "$temp_dir/autoinstall/meta-data"
    cp "$AUTOINSTALL_DIR/grub.cfg" "$temp_dir/autoinstall/grub.cfg"
    copy_user_data "$temp_dir/autoinstall"

    mkdir -p "$target_autoinstall"
    cp "$temp_dir/autoinstall/meta-data" "$target_autoinstall/meta-data"
    cp "$temp_dir/autoinstall/user-data" "$target_autoinstall/user-data"
    cp "$temp_dir/autoinstall/grub.cfg" "$target_autoinstall/grub.cfg"

    if [[ -d "$usb_mount/boot/grub" ]]; then
        if [[ -f "$usb_mount/boot/grub/grub.cfg" ]]; then
            cp "$usb_mount/boot/grub/grub.cfg" "$usb_mount/boot/grub/grub.cfg.bak.$(date +%Y%m%d%H%M%S)"
        fi

        cp "$AUTOINSTALL_DIR/grub.cfg" "$usb_mount/boot/grub/grub.cfg"
    else
        echo "WARN: $usb_mount/boot/grub not found. Autoinstall files were copied, but GRUB was not patched."
    fi

    sync

    echo
    echo "Rescue USB prepared successfully."
    echo
    echo "Copied autoinstall files to:"
    echo "  $target_autoinstall"
    echo
    echo "Target profile:"
    echo "  LISA Edge Rescue OS on eMMC"
}

main "$@"
