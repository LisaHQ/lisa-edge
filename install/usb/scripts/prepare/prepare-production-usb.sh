#!/usr/bin/env bash
# Prepare an Ubuntu installation USB for unattended LISA Edge deployment.
# This is the Unix/Linux counterpart of prepare-production-usb.cmd.

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
USB_ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
AUTOINSTALL_DIR="$USB_ROOT_DIR/config/production"
USER_DATA="$AUTOINSTALL_DIR/user-data"
USER_DATA_TEMPLATE="$AUTOINSTALL_DIR/user-data.template"
META_DATA="$AUTOINSTALL_DIR/meta-data"
GRUB_CFG="$AUTOINSTALL_DIR/grub.cfg"

STEP_TOTAL=9
USB_ROOT=""
AUTO_DETECT=0
ASSUME_YES=0
DRY_RUN=0
CONFIG_ONLY=0
TIMESTAMP=""
BACKUP_ROOT=""
HAS_EXISTING=0
BACKUP_USER_DATA=""
BACKUP_META_DATA=""
BACKUP_GRUB_CFG=""
CURRENT_STEP=""
CURRENT_LABEL=""

if [[ -t 1 && "${TERM:-}" != "dumb" ]]; then
    IS_TTY=1
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    BLUE=$'\033[34m'
    CYAN=$'\033[36m'
else
    IS_TTY=0
    RESET=""
    BOLD=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
fi

usage() {
    cat <<EOF
Usage:
  $(basename "$0") [options] <usb-mount-path>
  $(basename "$0") --auto-detect [options]
  $(basename "$0") --config-only

Options:
  -a, --auto-detect  Find a mounted Ubuntu installer USB automatically.
  -y, --yes          Do not ask before overwriting existing target files.
      --dry-run      Validate and show actions without changing the USB.
      --config-only  Create/validate autoinstall/user-data without a USB.
  -h, --help         Show this help.

Examples:
  $(basename "$0") /media/\$USER/UBUNTU
  $(basename "$0") --auto-detect
  $(basename "$0") --dry-run /media/\$USER/UBUNTU
  $(basename "$0") --config-only
EOF
}

error_message() {
    printf '%sError:%s %s\n' "$RED" "$RESET" "$*" >&2
}

info_message() {
    printf '%s%s%s\n' "$CYAN" "$*" "$RESET"
}

begin_step() {
    CURRENT_STEP="$1"
    CURRENT_LABEL="$2"
    if (( IS_TTY )); then
        printf '%s[....]%s [%s/%s] %s' "$BLUE" "$RESET" "$CURRENT_STEP" "$STEP_TOTAL" "$CURRENT_LABEL"
    fi
}

finish_step() {
    local tag="$1"
    local color="$2"
    local detail="${3:-}"
    if (( IS_TTY )); then
        printf '\r\033[2K'
    fi
    printf '%s[%s]%s [%s/%s] %s' "$color" "$tag" "$RESET" "$CURRENT_STEP" "$STEP_TOTAL" "$CURRENT_LABEL"
    [[ -n "$detail" ]] && printf ' - %s' "$detail"
    printf '\n'
}

step_done() { finish_step "DONE" "$GREEN" "${1:-}"; }
step_pass() { finish_step "PASS" "$GREEN" "${1:-}"; }
step_fail() { finish_step "FAIL" "$RED" "${1:-}"; }
step_skip() { finish_step "SKIP" "$YELLOW" "${1:-}"; }
# shellcheck disable=SC2120
step_sim()  { finish_step "SIM " "$CYAN" "${1:-}"; }

banner() {
    printf '\n%s%s=================================================================%s\n' "$BOLD" "$CYAN" "$RESET"
    printf '%s%s             LISA Edge - Ubuntu USB Preparation             %s\n' "$BOLD" "$CYAN" "$RESET"
    printf '%s%s=================================================================%s\n\n' "$BOLD" "$CYAN" "$RESET"
}

parse_args() {
    if (( $# == 0 )); then
        usage >&2
        return 1
    fi

    while (( $# > 0 )); do
        case "$1" in
            -a|--auto-detect)
                AUTO_DETECT=1
                ;;
            -y|--yes)
                ASSUME_YES=1
                ;;
            --dry-run)
                DRY_RUN=1
                ;;
            --config-only)
                CONFIG_ONLY=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                if (( $# > 1 )); then
                    error_message "Only one USB mount path may be specified."
                    return 1
                fi
                [[ $# -eq 1 ]] && USB_ROOT="$1"
                break
                ;;
            -*)
                error_message "Unknown option: $1"
                usage >&2
                return 1
                ;;
            *)
                if [[ -n "$USB_ROOT" ]]; then
                    error_message "Only one USB mount path may be specified."
                    return 1
                fi
                USB_ROOT="$1"
                ;;
        esac
        shift
    done

    if (( CONFIG_ONLY )); then
        return 0
    fi

    if [[ -z "$USB_ROOT" && $AUTO_DETECT -eq 0 && $DRY_RUN -eq 0 ]]; then
        error_message "Specify a USB mount path or use --auto-detect."
        usage >&2
        return 1
    fi

    return 0
}

is_ubuntu_installer_root() {
    local path="$1"
    [[ -d "$path/casper" && -d "$path/boot/grub" ]]
}

add_candidate() {
    local path="$1"
    local existing
    is_ubuntu_installer_root "$path" || return 0
    for existing in "${USB_CANDIDATES[@]}"; do
        [[ "$existing" == "$path" ]] && return 0
    done
    USB_CANDIDATES+=("$path")
}

find_usb_candidates() {
    local path
    USB_CANDIDATES=()
    shopt -s nullglob
    for path in \
        /media/* /media/*/* \
        /run/media/* /run/media/*/* \
        /mnt /mnt/* \
        /Volumes/*; do
        [[ -d "$path" ]] && add_candidate "$path"
    done
    shopt -u nullglob
}

detect_usb_drive() {
    begin_step 1 "Detect Ubuntu installer USB"

    if (( CONFIG_ONLY )); then
        step_skip "configuration-only mode"
        return 0
    fi

    if [[ -n "$USB_ROOT" ]]; then
        USB_ROOT="${USB_ROOT%/}"
        [[ -n "$USB_ROOT" ]] || USB_ROOT="/"
        step_done "$USB_ROOT"
        return 0
    fi

    find_usb_candidates
    if (( ${#USB_CANDIDATES[@]} == 0 )); then
        step_fail "no mounted Ubuntu installer USB found"
        error_message "Mount the USB and pass its path explicitly."
        return 1
    fi
    if (( ${#USB_CANDIDATES[@]} > 1 )); then
        step_fail "multiple installer USBs found"
        printf 'Candidates:\n' >&2
        local candidate
        for candidate in "${USB_CANDIDATES[@]}"; do
            printf '  - %s\n' "$candidate" >&2
        done
        error_message "Pass the intended mount path explicitly."
        return 1
    fi

    USB_ROOT="${USB_CANDIDATES[0]}"
    step_done "$USB_ROOT"
}

validate_usb_drive() {
    begin_step 2 "Validate Ubuntu installer layout"

    if (( CONFIG_ONLY )); then
        step_skip "configuration-only mode"
        return 0
    fi

    if [[ ! -d "$USB_ROOT" ]]; then
        step_fail "mount path does not exist"
        error_message "$USB_ROOT"
        return 1
    fi
    if ! is_ubuntu_installer_root "$USB_ROOT"; then
        step_fail "casper or boot/grub is missing"
        error_message "The selected path does not look like an Ubuntu installer USB: $USB_ROOT"
        return 1
    fi

    USB_ROOT="$(cd "$USB_ROOT" && pwd -P)"
    step_pass "$USB_ROOT"
}

validate_ssh_key() {
    case "$1" in
        ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-*\ *|sk-ssh-*\ *|sk-ecdsa-*\ *) return 0 ;;
        *) return 1 ;;
    esac
}

show_disk_help() {
    cat <<EOF

Disk discovery commands:
  Linux:  lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN
          udevadm info --query=property --name=/dev/sda | grep ID_SERIAL
  macOS:  diskutil list
          system_profiler SPNVMeDataType SPSerialATADataType

Use a stable serial when possible. Avoid selecting the installer USB.
EOF
}

generate_user_data() {
    local ssh_key="$1"
    local disk_mode="$2"
    local disk_value="$3"
    local git_ref="$4"
    local ssh_count disk_count git_count temp_file line indent escaped replacement

    ssh_count="$(grep -Ec '^[[:space:]]*-[[:space:]]*ssh-ed25519 REPLACE_WITH_YOUR_PUBLIC_KEY lisa-edge-admin[[:space:]]*$' "$USER_DATA_TEMPLATE" || true)"
    disk_count="$(grep -Ec '^[[:space:]]*serial:[[:space:]]*REPLACE_WITH_TARGET_DISK_SERIAL[[:space:]]*$' "$USER_DATA_TEMPLATE" || true)"
    git_count="$(grep -c 'REPLACE_WITH_LISA_EDGE_GIT_REF' "$USER_DATA_TEMPLATE" || true)"
    if [[ "$ssh_count" != "1" || "$disk_count" != "1" || "$git_count" != "1" ]]; then
        error_message "Template placeholders are missing or duplicated."
        return 1
    fi

    temp_file="$(mktemp "$AUTOINSTALL_DIR/.user-data.XXXXXX")" || {
        error_message "Cannot create a temporary file in $AUTOINSTALL_DIR"
        return 1
    }

    escaped="${disk_value//\'/\'\'}"
    case "$disk_mode" in
        largest) replacement="size: largest" ;;
        serial)  replacement="serial: '$escaped'" ;;
        model)   replacement="model: '$escaped'" ;;
        *)
            rm -f "$temp_file"
            error_message "Unsupported disk match mode: $disk_mode"
            return 1
            ;;
    esac

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^([[:space:]]*)-[[:space:]]*ssh-ed25519[[:space:]]+REPLACE_WITH_YOUR_PUBLIC_KEY[[:space:]]+lisa-edge-admin[[:space:]]*$ ]]; then
            indent="${BASH_REMATCH[1]}"
            printf '%s- %s\n' "$indent" "$ssh_key" >>"$temp_file"
        elif [[ "$line" =~ ^([[:space:]]*)serial:[[:space:]]*REPLACE_WITH_TARGET_DISK_SERIAL[[:space:]]*$ ]]; then
            indent="${BASH_REMATCH[1]}"
            printf '%s%s\n' "$indent" "$replacement" >>"$temp_file"
        elif [[ "$line" == *REPLACE_WITH_LISA_EDGE_GIT_REF* ]]; then
            printf '%s\n' "${line/REPLACE_WITH_LISA_EDGE_GIT_REF/$git_ref}" >>"$temp_file"
        else
            printf '%s\n' "$line" >>"$temp_file"
        fi
    done <"$USER_DATA_TEMPLATE"

    if grep -Eq 'REPLACE_WITH_|YOUR_|CHANGEME' "$temp_file"; then
        rm -f "$temp_file"
        error_message "Generated user-data still contains placeholder values."
        return 1
    fi

    chmod 0600 "$temp_file" 2>/dev/null || true
    if ! mv -f "$temp_file" "$USER_DATA"; then
        rm -f "$temp_file"
        error_message "Cannot write $USER_DATA"
        return 1
    fi
}

config_wizard() {
    local ssh_key=""
    local local_key=""
    local answer=""
    local disk_choice=""
    local disk_mode=""
    local disk_value=""
    local git_ref=""

    printf '\n%s%s-------------------------- Config Wizard --------------------------%s\n' "$BOLD" "$CYAN" "$RESET"
    printf 'This creates: %s\n\n' "$USER_DATA"

    if [[ -n "${HOME:-}" && -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        local_key="$(head -n 1 "$HOME/.ssh/id_ed25519.pub")"
        if validate_ssh_key "$local_key"; then
            printf 'Detected SSH public key:\n  %s\n' "$local_key"
            printf 'Use this key? [Y/n]: '
            IFS= read -r answer || answer=""
            case "$answer" in
                ""|y|Y|yes|YES|Yes) ssh_key="$local_key" ;;
            esac
        fi
    fi

    while [[ -z "$ssh_key" ]]; do
        printf 'Paste the complete SSH public key: '
        IFS= read -r ssh_key || ssh_key=""
        if ! validate_ssh_key "$ssh_key"; then
            error_message "Unsupported or invalid public key format."
            printf 'Create one with: ssh-keygen -t ed25519 -C lisa-edge-admin\n'
            ssh_key=""
        fi
    done

    while [[ -z "$disk_mode" ]]; do
        cat <<EOF

Select the target installation disk match:
  1) Disk serial (recommended)
  2) Largest disk (destructive; explicit confirmation required)
  3) Disk model
  4) Show disk discovery help and stop
EOF
        printf 'Choice [1]: '
        IFS= read -r disk_choice || disk_choice=""
        [[ -z "$disk_choice" ]] && disk_choice="1"
        case "$disk_choice" in
            1)
                printf 'Target disk serial: '
                IFS= read -r disk_value || disk_value=""
                if [[ -n "$disk_value" ]]; then
                    disk_mode="serial"
                else
                    error_message "Disk serial cannot be empty."
                fi
                ;;
            2)
                printf '%sWARNING:%s Ubuntu will install to the largest detected disk.\n' "$YELLOW" "$RESET"
                printf 'Type LARGEST to confirm: '
                IFS= read -r answer || answer=""
                answer="$(printf '%s' "$answer" | tr '[:lower:]' '[:upper:]')"
                if [[ "$answer" == "LARGEST" ]]; then
                    disk_mode="largest"
                    disk_value="largest"
                else
                    error_message "Largest-disk selection was not confirmed."
                fi
                ;;
            3)
                printf 'Target disk model: '
                IFS= read -r disk_value || disk_value=""
                if [[ -n "$disk_value" ]]; then
                    disk_mode="model"
                else
                    error_message "Disk model cannot be empty."
                fi
                ;;
            4)
                show_disk_help
                error_message "Configuration stopped so you can identify the target disk."
                return 1
                ;;
            *) error_message "Choose a number from 1 to 4." ;;
        esac
    done

    printf '\nGit branch or release tag [main]: '
    IFS= read -r git_ref || git_ref=""
    git_ref="${git_ref:-main}"
    if [[ ! "$git_ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ || "$git_ref" == *..* ]]; then
        error_message "Git ref contains unsupported characters."
        return 1
    fi

    if ! generate_user_data "$ssh_key" "$disk_mode" "$disk_value" "$git_ref"; then
        return 1
    fi
    printf '%sCreated:%s %s\n\n' "$GREEN" "$RESET" "$USER_DATA"
}

validate_source_files() {
    begin_step 3 "Validate autoinstall source files"

    if [[ ! -f "$USER_DATA" ]]; then
        if [[ ! -f "$USER_DATA_TEMPLATE" ]]; then
            step_fail "user-data and template are missing"
            return 1
        fi
        if (( DRY_RUN )); then
            step_fail "user-data is missing"
            error_message "Dry-run does not generate configuration. Run --config-only first."
            return 1
        fi
        if (( ASSUME_YES )); then
            step_fail "user-data is missing"
            error_message "The configuration wizard is interactive; run --config-only first."
            return 1
        fi
        step_skip "user-data missing; opening configuration wizard"
        config_wizard || return 1
        begin_step 3 "Validate autoinstall source files"
    fi

    if [[ ! -f "$META_DATA" ]]; then
        step_fail "meta-data is missing"
        error_message "$META_DATA"
        return 1
    fi
    if [[ ! -f "$GRUB_CFG" ]]; then
        step_fail "grub.cfg is missing"
        error_message "$GRUB_CFG"
        return 1
    fi
    if grep -Eq 'REPLACE_WITH_|YOUR_|CHANGEME' "$USER_DATA"; then
        step_fail "user-data contains placeholder values"
        error_message "Complete the configuration in $USER_DATA"
        return 1
    fi

    step_pass "user-data, meta-data and grub.cfg"
}

generate_timestamp() {
    TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
    if [[ -n "$USB_ROOT" ]]; then
        BACKUP_ROOT="$USB_ROOT/backups/$TIMESTAMP"
    fi
}

check_existing_files() {
    begin_step 4 "Check existing USB configuration"

    if (( CONFIG_ONLY )); then
        step_skip "configuration-only mode"
        return 0
    fi

    HAS_EXISTING=0
    [[ -f "$USB_ROOT/autoinstall/user-data" ]] && HAS_EXISTING=1 && BACKUP_USER_DATA="$BACKUP_ROOT/autoinstall/user-data"
    [[ -f "$USB_ROOT/autoinstall/meta-data" ]] && HAS_EXISTING=1 && BACKUP_META_DATA="$BACKUP_ROOT/autoinstall/meta-data"
    [[ -f "$USB_ROOT/boot/grub/grub.cfg" ]] && HAS_EXISTING=1 && BACKUP_GRUB_CFG="$BACKUP_ROOT/boot/grub/grub.cfg"

    if (( HAS_EXISTING )); then
        step_done "existing files will be backed up"
    else
        step_done "no existing target files"
    fi
}

print_plan() {
    (( CONFIG_ONLY || DRY_RUN || ASSUME_YES || ! HAS_EXISTING )) && return 0
    cat <<EOF

Planned changes:
  Mode:         apply
  Source:       $AUTOINSTALL_DIR
  USB:          $USB_ROOT
  user-data:    $USB_ROOT/autoinstall/user-data
  meta-data:    $USB_ROOT/autoinstall/meta-data
  grub.cfg:     $USB_ROOT/boot/grub/grub.cfg
  Backup root:  $BACKUP_ROOT
EOF
    [[ -n "$BACKUP_USER_DATA" ]] && printf '  Backup:       %s\n' "$BACKUP_USER_DATA"
    [[ -n "$BACKUP_META_DATA" ]] && printf '  Backup:       %s\n' "$BACKUP_META_DATA"
    [[ -n "$BACKUP_GRUB_CFG" ]] && printf '  Backup:       %s\n' "$BACKUP_GRUB_CFG"
}

confirm_changes() {
    local answer=""
    (( CONFIG_ONLY || DRY_RUN || ASSUME_YES || ! HAS_EXISTING )) && return 0
    printf '\nExisting USB configuration will be replaced. Type YES to continue: '
    IFS= read -r answer || answer=""
    answer="$(printf '%s' "$answer" | tr '[:lower:]' '[:upper:]')"
    if [[ "$answer" != "YES" ]]; then
        error_message "Cancelled; no files were changed."
        return 1
    fi
}

validate_write_access() {
    begin_step 5 "Validate USB write access"

    if (( CONFIG_ONLY )); then
        step_skip "configuration-only mode"
        return 0
    fi
    if (( DRY_RUN )); then
        step_skip "dry-run mode"
        return 0
    fi

    local test_file="$USB_ROOT/.lisa-edge-write-test-$$"
    if ! printf 'write-test\n' >"$test_file" 2>/dev/null; then
        step_fail "USB is not writable"
        error_message "Check mount permissions or remount the USB read-write."
        return 1
    fi
    rm -f "$test_file"
    step_pass "write access confirmed"
}

prepare_targets() {
    begin_step 6 "Prepare target directories"

    if (( CONFIG_ONLY )); then
        step_skip "configuration-only mode"
        return 0
    fi
    if (( DRY_RUN )); then
        step_sim
        printf 'Would create:\n'
        printf '  %s\n' "$USB_ROOT/autoinstall"
        printf '  %s\n' "$BACKUP_ROOT/autoinstall"
        printf '  %s\n' "$BACKUP_ROOT/boot/grub"
        return 0
    fi

    if ! mkdir -p "$USB_ROOT/autoinstall" "$USB_ROOT/boot/grub"; then
        step_fail "cannot create target directories"
        return 1
    fi
    if ! mkdir -p "$BACKUP_ROOT/autoinstall" "$BACKUP_ROOT/boot/grub"; then
        step_fail "cannot create backup directories"
        return 1
    fi
    step_done
}

backup_existing_files() {
    begin_step 7 "Back up existing USB configuration"

    if (( CONFIG_ONLY )); then
        step_skip "configuration-only mode"
        return 0
    fi
    if (( DRY_RUN )); then
        step_sim
        if (( HAS_EXISTING )); then
            printf 'Would back up:\n'
            [[ -n "$BACKUP_USER_DATA" ]] && printf '  %s -> %s\n' "$USB_ROOT/autoinstall/user-data" "$BACKUP_USER_DATA"
            [[ -n "$BACKUP_META_DATA" ]] && printf '  %s -> %s\n' "$USB_ROOT/autoinstall/meta-data" "$BACKUP_META_DATA"
            [[ -n "$BACKUP_GRUB_CFG" ]] && printf '  %s -> %s\n' "$USB_ROOT/boot/grub/grub.cfg" "$BACKUP_GRUB_CFG"
        fi
        return 0
    fi

    if [[ -n "$BACKUP_USER_DATA" ]] && ! mv "$USB_ROOT/autoinstall/user-data" "$BACKUP_USER_DATA"; then
        step_fail "could not back up user-data"
        return 1
    fi
    if [[ -n "$BACKUP_META_DATA" ]] && ! mv "$USB_ROOT/autoinstall/meta-data" "$BACKUP_META_DATA"; then
        step_fail "could not back up meta-data"
        return 1
    fi
    if [[ -n "$BACKUP_GRUB_CFG" ]] && ! mv "$USB_ROOT/boot/grub/grub.cfg" "$BACKUP_GRUB_CFG"; then
        step_fail "could not back up grub.cfg"
        return 1
    fi
    if (( HAS_EXISTING )); then
        step_done "$BACKUP_ROOT"
    else
        step_done "no existing files"
    fi
}

copy_files() {
    begin_step 8 "Copy LISA Edge autoinstall files"

    if (( CONFIG_ONLY )); then
        step_skip "configuration-only mode"
        return 0
    fi
    if (( DRY_RUN )); then
        step_sim
        printf 'Would copy:\n'
        printf '  %s -> %s\n' "$USER_DATA" "$USB_ROOT/autoinstall/user-data"
        printf '  %s -> %s\n' "$META_DATA" "$USB_ROOT/autoinstall/meta-data"
        printf '  %s -> %s\n' "$GRUB_CFG" "$USB_ROOT/boot/grub/grub.cfg"
        return 0
    fi

    if ! cp "$USER_DATA" "$USB_ROOT/autoinstall/user-data" ||
       ! cp "$META_DATA" "$USB_ROOT/autoinstall/meta-data" ||
       ! cp "$GRUB_CFG" "$USB_ROOT/boot/grub/grub.cfg"; then
        step_fail "copy failed"
        error_message "Review the backup at $BACKUP_ROOT before retrying."
        return 1
    fi
    sync
    step_done "three files copied"
}

verify_copy() {
    begin_step 9 "Verify copied files"

    if (( CONFIG_ONLY )); then
        step_skip "configuration-only mode"
        return 0
    fi
    if (( DRY_RUN )); then
        step_skip "dry-run mode"
        return 0
    fi

    if ! cmp -s "$USER_DATA" "$USB_ROOT/autoinstall/user-data" ||
       ! cmp -s "$META_DATA" "$USB_ROOT/autoinstall/meta-data" ||
       ! cmp -s "$GRUB_CFG" "$USB_ROOT/boot/grub/grub.cfg"; then
        step_fail "copied content does not match source"
        return 1
    fi
    step_pass "all copied files match"
}

print_rollback_command() {
    local backup="$1"
    local target="$2"
    [[ -z "$backup" ]] && return 0
    printf '  cp -f '
    printf '%q ' "$backup"
    printf '%q\n' "$target"
}

finish() {
    printf '\n%s%s=================================================================%s\n' "$BOLD" "$GREEN" "$RESET"
    if (( CONFIG_ONLY )); then
        printf '%s%s Configuration is ready.%s\n' "$BOLD" "$GREEN" "$RESET"
        printf '%s%s=================================================================%s\n' "$BOLD" "$GREEN" "$RESET"
        printf '\nGenerated/validated files:\n  %s\n  %s\n  %s\n' "$USER_DATA" "$META_DATA" "$GRUB_CFG"
        printf '\nNext: run this script with the mounted Ubuntu USB path.\n'
        return 0
    fi
    if (( DRY_RUN )); then
        printf '%s%s Dry-run completed; no USB files were changed.%s\n' "$BOLD" "$GREEN" "$RESET"
    else
        printf '%s%s Ubuntu installer USB is ready.%s\n' "$BOLD" "$GREEN" "$RESET"
    fi
    printf '%s%s=================================================================%s\n' "$BOLD" "$GREEN" "$RESET"
    printf '\nUSB: %s\n' "$USB_ROOT"

    printf 'Installed files:\n  %s\n  %s\n  %s\n' \
        "$USB_ROOT/autoinstall/user-data" \
        "$USB_ROOT/autoinstall/meta-data" \
        "$USB_ROOT/boot/grub/grub.cfg"

    if (( HAS_EXISTING )); then
        printf '\nBackup files:\n'
        [[ -n "$BACKUP_USER_DATA" ]] && printf '  %s\n' "$BACKUP_USER_DATA"
        [[ -n "$BACKUP_META_DATA" ]] && printf '  %s\n' "$BACKUP_META_DATA"
        [[ -n "$BACKUP_GRUB_CFG" ]] && printf '  %s\n' "$BACKUP_GRUB_CFG"
    fi

    if (( DRY_RUN )); then
        return 0
    fi

    if (( HAS_EXISTING )); then
        printf '\nRollback commands (run only if required):\n'
        print_rollback_command "$BACKUP_USER_DATA" "$USB_ROOT/autoinstall/user-data"
        print_rollback_command "$BACKUP_META_DATA" "$USB_ROOT/autoinstall/meta-data"
        print_rollback_command "$BACKUP_GRUB_CFG" "$USB_ROOT/boot/grub/grub.cfg"
    fi

    cat <<EOF

Next steps:
  1. Safely eject the USB.
  2. Insert it into the target hardware.
  3. Boot from the USB in UEFI mode.
  4. Verify that autoinstall starts automatically on the intended disk.
EOF
}

main() {
    parse_args "$@" || exit 1
    banner
    detect_usb_drive || exit 1
    validate_usb_drive || exit 1
    validate_source_files || exit 1
    generate_timestamp
    check_existing_files || exit 1
    print_plan
    confirm_changes || exit 1
    validate_write_access || exit 1
    prepare_targets || exit 1
    backup_existing_files || exit 1
    copy_files || exit 1
    verify_copy || exit 1
    finish
}

main "$@"
