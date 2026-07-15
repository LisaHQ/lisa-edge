#!/usr/bin/env bash

UI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$UI_DIR/../../../lib/paths.sh"

info() { printf '[LISA] %s\n' "$*"; }
warn() { printf '[LISA] WARNING: %s\n' "$*" >&2; }
die() { printf '[LISA] ERROR: %s\n' "$*" >&2; exit 1; }

ask_value() {
  local variable="$1"
  local label="$2"
  local default_value="${3:-}"
  local value

  if [ -n "$default_value" ]; then
    read -r -p "$label [$default_value]: " value
    value="${value:-$default_value}"
  else
    read -r -p "$label: " value
  fi
  printf -v "$variable" '%s' "$value"
}

ask_secret() {
  local variable="$1"
  local label="$2"
  local current_value="${3:-}"
  local value

  if [ -n "$current_value" ]; then
    read -r -s -p "$label [press Enter to keep current value]: " value
    echo
    value="${value:-$current_value}"
  else
    read -r -s -p "$label [leave empty to auto-generate/skip]: " value
    echo
  fi
  printf -v "$variable" '%s' "$value"
}

ask_yes_no() {
  local variable="$1"
  local label="$2"
  local default_value="${3:-no}"
  local prompt="[y/N]"
  local input

  [ "$default_value" = "yes" ] && prompt="[Y/n]"
  while true; do
    read -r -p "$label $prompt: " input
    input="${input:-$default_value}"
    case "${input,,}" in
      y|yes) printf -v "$variable" '%s' "yes"; return 0 ;;
      n|no) printf -v "$variable" '%s' "no"; return 0 ;;
      *) echo "Please answer yes or no." ;;
    esac
  done
}

require_absolute_path() {
  local label="$1"
  local value="$2"
  case "$value" in
    /*) ;;
    *) die "$label must be an absolute path: $value" ;;
  esac
  [ "$value" != "/" ] || die "$label cannot be /."
}

require_persistent_data_path() {
  local label="$1"
  local value="$2"
  lisa_validate_persistent_path "$label" "$value" || die "Unsafe persistent-data path."
}

require_port() {
  local label="$1"
  local value="$2"
  [[ "$value" =~ ^[0-9]+$ ]] || die "$label must be numeric."
  [ "$value" -ge 1 ] && [ "$value" -le 65535 ] || die "$label must be between 1 and 65535."
}

require_bind_address() {
  local label="$1"
  local value="$2"
  local octet
  local octets=()

  [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die "$label must be an IPv4 bind address."
  IFS=. read -r -a octets <<< "$value"
  for octet in "${octets[@]}"; do
    [ "$octet" -le 255 ] || die "$label contains an invalid IPv4 octet."
  done
}

generate_hex_secret() {
  od -An -N24 -tx1 /dev/urandom | tr -d ' \n'
}
