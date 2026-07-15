#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INSTALLER_DIR="${INSTALLER_DIR:-$REPO_ROOT/usb-installer}"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/build/usb}"

usage() {
    cat <<'EOF'
Usage:
  tools/build-usb.sh <profile> [output-dir]

Examples:
  tools/build-usb.sh production
  tools/build-usb.sh rescue
  tools/build-usb.sh production /tmp/lisa-edge-usb

Expected layout:
  usb-installer/
  ├── production/
  │   └── autoinstall
  │       ├── user-data
  │       └── meta-data
  └── rescue/
      └── autoinstall
          ├── user-data
          └── meta-data

This script prepares autoinstall files for copying to a USB drive.
It does not format or write to disks.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

main() {
    local profile="${1:-}"
    local output_dir="${2:-}"

    if [[ -z "$profile" || "$profile" == "-h" || "$profile" == "--help" ]]; then
        usage
        exit 0
    fi

    local source_dir="$INSTALLER_DIR/$profile"

    if [[ -z "$output_dir" ]]; then
        output_dir="$BUILD_DIR/$profile"
    fi

    [[ -d "$source_dir" ]] || die "installer profile not found: $source_dir"
    [[ -f "$source_dir/autoinstall/user-data" ]] || die "missing user-data in $source_dir"
    [[ -f "$source_dir/autoinstall/meta-data" ]] || die "missing meta-data in $source_dir"

    rm -rf "$output_dir"
    mkdir -p "$output_dir"

    cp -R "$source_dir/." "$output_dir/"

    echo
    echo "USB payload prepared:"
    echo "  $output_dir"
    echo
    echo "Files:"
    find "$output_dir" -maxdepth 2 -type f -printf "  %P\n" | sort
}

main "$@"
