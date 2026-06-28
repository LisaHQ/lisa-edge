#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# LISA Edge - Ubuntu USB Preparation Tool
# ============================================================
# Purpose:
#   Prepare an Ubuntu Server USB installer for unattended
#   LISA Edge Production deployment.
#
# Behavior:
#   - Detects the Ubuntu USB installer automatically when possible.
#   - Validates required autoinstall files.
#   - Refuses to use user-data when common placeholders remain.
#   - Validates USB write access before modifying files.
#   - Backs up existing target files before replacing them.
#   - Verifies copied files after installation.
#   - Supports dry-run and non-interactive execution.
#
# Usage:
#   ./prepare-ubuntu-usb.sh [OPTIONS] [USB_MOUNT]
#
# Options:
#   --dry-run     Validate and display actions without modifying USB.
#   --yes         Skip confirmation prompt.
#   --help        Show this help message.
#
# Examples:
#   ./prepare-ubuntu-usb.sh
#   ./prepare-ubuntu-usb.sh /media/$USER/Ubuntu-Server
#   ./prepare-ubuntu-usb.sh --dry-run
#   ./prepare-ubuntu-usb.sh --dry-run /media/$USER/Ubuntu-Server
#   ./prepare-ubuntu-usb.sh --yes /media/$USER/Ubuntu-Server
#
# Backup example:
#   /media/user/Ubuntu-Server/backups/20260617-153012/
#   ├── autoinstall/
#   │   ├── user-data
#   │   └── meta-data
#   └── boot/
#       └── grub/
#           └── grub.cfg
# ============================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
AUTOINSTALL_DIR="${PROJECT_ROOT}/production/autoinstall"

USB_MOUNT=""
BACKUP_TS=""
DRY_RUN=0
ASSUME_YES=0

USER_DATA_SOURCE=""
META_DATA_SOURCE=""
GRUB_CFG_SOURCE=""

STEP_TOTAL=8

banner() {
    echo
    echo "============================================================"
    echo " LISA Edge - Ubuntu USB Preparation Tool"
    echo "============================================================"
    echo
}

log_step() {
    local step="$1"
    local message="$2"
    echo "[LISA] [${step}/${STEP_TOTAL}] ${message}"
}

info() {
    echo "[LISA] $*"
}

error() {
    echo "ERROR: $*" >&2
}

usage() {
    cat <<'EOF'
Usage:
  ./prepare-ubuntu-usb.sh [OPTIONS] [USB_MOUNT]

Options:
  --dry-run     Validate and display actions without modifying USB.
  --yes         Skip confirmation prompt.
  --help        Show this help message.

Examples:
  ./prepare-ubuntu-usb.sh
  ./prepare-ubuntu-usb.sh /media/$USER/Ubuntu-Server
  ./prepare-ubuntu-usb.sh --dry-run
  ./prepare-ubuntu-usb.sh --dry-run /media/$USER/Ubuntu-Server
  ./prepare-ubuntu-usb.sh --yes /media/$USER/Ubuntu-Server
EOF
}

parse_args() {
    local arg=""

    while [[ $# -gt 0 ]]; do
        arg="$1"

        case "${arg}" in
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --yes|-y)
                ASSUME_YES=1
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                error "Unknown option: ${arg}"
                echo
                usage
                exit 1
                ;;
            *)
                if [[ -n "${USB_MOUNT}" ]]; then
                    error "Only one USB mount path may be provided."
                    echo
                    usage
                    exit 1
                fi
                USB_MOUNT="${arg}"
                shift
                ;;
        esac
    done

    if [[ $# -gt 0 ]]; then
        if [[ -n "${USB_MOUNT}" ]]; then
            error "Only one USB mount path may be provided."
            echo
            usage
            exit 1
        fi
        USB_MOUNT="$1"
    fi
}

detect_usb_mount() {
    if [[ -n "${USB_MOUNT}" ]]; then
        return 0
    fi

    log_step 1 "Searching mounted volumes for Ubuntu USB installer..."

    local candidate
    local candidates=()

    while IFS= read -r candidate; do
        [[ -n "${candidate}" ]] && candidates+=("${candidate}")
    done < <(
        {
            find /media "${HOME}/media" /run/media /mnt /Volumes \
                -mindepth 1 -maxdepth 3 -type d 2>/dev/null || true
        } | sort -u
    )

    for candidate in "${candidates[@]}"; do
        if [[ -d "${candidate}/casper" && -d "${candidate}/boot/grub" ]]; then
            USB_MOUNT="${candidate}"
            return 0
        fi
    done

    error "Could not auto-detect the Ubuntu USB installer."
    echo
    usage
    return 1
}

validate_usb_mount() {
    log_step 2 "Validating USB media..."

    if [[ ! -d "${USB_MOUNT}" ]]; then
        error "Mount point does not exist: ${USB_MOUNT}"
        return 1
    fi

    if [[ ! -d "${USB_MOUNT}/casper" ]]; then
        error "This does not look like an Ubuntu installer USB."
        echo "Missing directory:"
        echo "  ${USB_MOUNT}/casper"
        return 1
    fi

    if [[ ! -d "${USB_MOUNT}/boot/grub" ]]; then
        error "GRUB directory not found on USB."
        echo "Missing directory:"
        echo "  ${USB_MOUNT}/boot/grub"
        return 1
    fi
}

validate_source_files() {
    log_step 3 "Validating source files..."

    USER_DATA_SOURCE=""

    if [[ -f "${AUTOINSTALL_DIR}/user-data" ]]; then
        USER_DATA_SOURCE="${AUTOINSTALL_DIR}/user-data"
    elif [[ -f "${AUTOINSTALL_DIR}/user-data.template" ]]; then
        USER_DATA_SOURCE="${AUTOINSTALL_DIR}/user-data.template"
    fi

    if [[ -z "${USER_DATA_SOURCE}" ]]; then
        error "Missing user-data or user-data.template: ${AUTOINSTALL_DIR}"
        return 1
    fi

    if grep -Eq 'REPLACE_WITH_|YOUR_|CHANGEME' "${USER_DATA_SOURCE}"; then
        error "user-data still contains placeholder values."
        echo
        echo "File:"
        echo "  ${USER_DATA_SOURCE}"
        echo
        echo "Check values such as:"
        echo "  - SSD serial"
        echo "  - SSH public key"
        echo "  - Password hash"
        echo "  - Hostname"
        return 1
    fi

    META_DATA_SOURCE="${AUTOINSTALL_DIR}/meta-data"
    if [[ ! -f "${META_DATA_SOURCE}" ]]; then
        error "Missing meta-data: ${META_DATA_SOURCE}"
        return 1
    fi

    GRUB_CFG_SOURCE="${AUTOINSTALL_DIR}/grub.cfg"
    if [[ ! -f "${GRUB_CFG_SOURCE}" ]]; then
        error "Missing grub.cfg: ${GRUB_CFG_SOURCE}"
        return 1
    fi
}

generate_timestamp() {
    BACKUP_TS="$(date '+%Y%m%d-%H%M%S')"

    if [[ -z "${BACKUP_TS}" ]]; then
        error "Could not generate backup timestamp."
        return 1
    fi
}

print_plan() {
    echo "Mode:"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo "  DRY RUN - no files will be modified."
    else
        echo "  APPLY - USB files may be backed up and replaced."
    fi
    echo
    echo "Target USB:"
    echo "  ${USB_MOUNT}"
    echo
    echo "Source directory:"
    echo "  ${AUTOINSTALL_DIR}"
    echo
    echo "Files to install:"
    echo "  ${USB_MOUNT}/autoinstall/user-data"
    echo "  ${USB_MOUNT}/autoinstall/meta-data"
    echo "  ${USB_MOUNT}/boot/grub/grub.cfg"
    echo
    echo "Existing target files will be backed up under:"
    echo "  ${USB_MOUNT}/backups/${BACKUP_TS}/"
    echo
}

confirm() {
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        info "Dry-run mode enabled. Skipping confirmation."
        return 0
    fi

    if [[ "${ASSUME_YES}" -eq 1 ]]; then
        info "--yes enabled. Skipping confirmation."
        return 0
    fi

    local answer=""
    read -r -p "Type YES to continue: " answer
    if [[ "${answer}" != "YES" ]]; then
        echo "Aborted."
        return 1
    fi
}

validate_write_access() {
    log_step 4 "Validating USB write access..."

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        info "Dry-run mode enabled. Skipping write test."
        return 0
    fi

    local test_file="${USB_MOUNT}/.lisa-edge-write-test.$$"

    if ! : > "${test_file}"; then
        error "USB is not writable: ${USB_MOUNT}"
        return 1
    fi

    rm -f -- "${test_file}"
}

prepare_targets() {
    log_step 5 "Preparing target directories..."

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        info "Would create:"
        echo "  ${USB_MOUNT}/autoinstall"
        echo "  ${USB_MOUNT}/backups/${BACKUP_TS}/autoinstall"
        echo "  ${USB_MOUNT}/backups/${BACKUP_TS}/boot/grub"
        return 0
    fi

    mkdir -p "${USB_MOUNT}/autoinstall"
    mkdir -p "${USB_MOUNT}/backups/${BACKUP_TS}/autoinstall"
    mkdir -p "${USB_MOUNT}/backups/${BACKUP_TS}/boot/grub"
}

backup_existing_files() {
    log_step 6 "Backing up existing files..."

    backup_file \
        "${USB_MOUNT}/autoinstall/user-data" \
        "${USB_MOUNT}/backups/${BACKUP_TS}/autoinstall/user-data"

    backup_file \
        "${USB_MOUNT}/autoinstall/meta-data" \
        "${USB_MOUNT}/backups/${BACKUP_TS}/autoinstall/meta-data"

    backup_file \
        "${USB_MOUNT}/boot/grub/grub.cfg" \
        "${USB_MOUNT}/backups/${BACKUP_TS}/boot/grub/grub.cfg"
}

backup_file() {
    local target_file="$1"
    local backup_file="$2"

    if [[ -e "${target_file}" ]]; then
        if [[ "${DRY_RUN}" -eq 1 ]]; then
            echo "Would back up:"
            echo "  ${target_file}"
            echo "  -> ${backup_file}"
        else
            echo "Backing up:"
            echo "  ${target_file}"
            echo "  -> ${backup_file}"
            mv -- "${target_file}" "${backup_file}"
        fi
    else
        echo "No existing file to back up:"
        echo "  ${target_file}"
    fi
}

copy_files() {
    log_step 7 "Installing autoinstall configuration..."

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        info "Would copy:"
        echo "  ${USER_DATA_SOURCE}"
        echo "  -> ${USB_MOUNT}/autoinstall/user-data"
        echo "  ${META_DATA_SOURCE}"
        echo "  -> ${USB_MOUNT}/autoinstall/meta-data"
        echo "  ${GRUB_CFG_SOURCE}"
        echo "  -> ${USB_MOUNT}/boot/grub/grub.cfg"
        return 0
    fi

    cp -f -- "${USER_DATA_SOURCE}" "${USB_MOUNT}/autoinstall/user-data"
    cp -f -- "${META_DATA_SOURCE}" "${USB_MOUNT}/autoinstall/meta-data"
    cp -f -- "${GRUB_CFG_SOURCE}" "${USB_MOUNT}/boot/grub/grub.cfg"

    sync
}

verify_copy() {
    log_step 8 "Verifying installed files..."

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        info "Dry-run mode enabled. Skipping verification."
        return 0
    fi

    verify_file "${USER_DATA_SOURCE}" "${USB_MOUNT}/autoinstall/user-data"
    verify_file "${META_DATA_SOURCE}" "${USB_MOUNT}/autoinstall/meta-data"
    verify_file "${GRUB_CFG_SOURCE}" "${USB_MOUNT}/boot/grub/grub.cfg"
}

verify_file() {
    local source_file="$1"
    local target_file="$2"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        return 0
    fi

    if cmp -s -- "${source_file}" "${target_file}"; then
        echo "Verified:"
        echo "  ${target_file}"
        return 0
    fi

    error "Verification failed:"
    echo "  Source: ${source_file}"
    echo "  Target: ${target_file}"
    return 1
}

print_rollback_commands() {
    echo "Rollback commands:"
    echo "  cp -f '${USB_MOUNT}/backups/${BACKUP_TS}/autoinstall/user-data' '${USB_MOUNT}/autoinstall/user-data'"
    echo "  cp -f '${USB_MOUNT}/backups/${BACKUP_TS}/autoinstall/meta-data' '${USB_MOUNT}/autoinstall/meta-data'"
    echo "  cp -f '${USB_MOUNT}/backups/${BACKUP_TS}/boot/grub/grub.cfg' '${USB_MOUNT}/boot/grub/grub.cfg'"
}

finish() {
    echo
    echo "============================================================"
    if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo "Dry Run Complete"
    else
        echo "Installation Complete"
    fi
    echo "============================================================"
    echo
    echo "USB Mount:"
    echo "  ${USB_MOUNT}"
    echo
    echo "Backup:"
    echo "  ${USB_MOUNT}/backups/${BACKUP_TS}"
    echo
    echo "Installed:"
    echo "  ${USB_MOUNT}/autoinstall/user-data"
    echo "  ${USB_MOUNT}/autoinstall/meta-data"
    echo "  ${USB_MOUNT}/boot/grub/grub.cfg"
    echo
    print_rollback_commands
    echo
    echo "Next Steps:"
    echo "  1. Safely eject the USB."
    echo "  2. Insert into target hardware."
    echo "  3. Boot from USB."
    echo "  4. Verify autoinstall starts automatically."
    echo
}

main() {
    parse_args "$@"
    banner
    detect_usb_mount
    validate_usb_mount
    validate_source_files
    generate_timestamp
    print_plan
    confirm
    validate_write_access
    prepare_targets
    backup_existing_files
    copy_files
    verify_copy
    finish
}

main "$@"
