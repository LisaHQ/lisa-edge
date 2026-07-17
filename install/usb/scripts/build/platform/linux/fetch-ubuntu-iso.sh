#!/usr/bin/env bash
# Download and verify the Ubuntu Server ISO defined in config/ubuntu-releases.json.
#
# Prints the absolute path of the verified ISO as the LAST line on stdout.
# All progress and diagnostics go to stderr so callers can capture the path:
#   iso_path="$(bash fetch-ubuntu-iso.sh | tail -n 1)"
#
# The ISO is cached outside the repository and reused when its checksum
# still matches (idempotent, resume-friendly, fail-closed on mismatch).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# SCRIPT_DIR = install/usb/scripts/build/platform/linux -> install/usb is 4 levels up.
USB_ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd -P)"
DEFAULT_CONFIG="$USB_ROOT_DIR/config/ubuntu-releases.json"
DEFAULT_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/lisa-edge/iso"

CONFIG_FILE="$DEFAULT_CONFIG"
CACHE_DIR="$DEFAULT_CACHE"
RELEASE=""
OFFLINE=0

log()  { printf '%s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    cat >&2 <<EOF
Usage:
  $(basename "$0") [options]

Options:
  -r, --release <series>   Release series key from ubuntu-releases.json
                           (default: the file's "default" entry).
      --config <path>      Alternative ubuntu-releases.json.
      --cache-dir <path>   ISO cache directory (default: $DEFAULT_CACHE).
      --offline            Never touch the network; succeed only when a
                           verified ISO is already cached.
  -h, --help               Show this help.

The verified ISO path is printed as the last line on stdout.
EOF
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            -r|--release)  [[ -n "${2:-}" ]] || die "missing value for $1"; RELEASE="$2"; shift 2 ;;
            --config)      [[ -n "${2:-}" ]] || die "missing value for $1"; CONFIG_FILE="$2"; shift 2 ;;
            --cache-dir)   [[ -n "${2:-}" ]] || die "missing value for $1"; CACHE_DIR="$2"; shift 2 ;;
            --offline)     OFFLINE=1; shift ;;
            -h|--help)     usage; exit 0 ;;
            *)             usage; die "unknown argument: $1" ;;
        esac
    done
}

require_tools() {
    command -v sha256sum >/dev/null || die "sha256sum is required"
    if (( ! OFFLINE )); then
        command -v curl >/dev/null || die "curl is required (apt install curl)"
    fi
    command -v jq >/dev/null || command -v python3 >/dev/null ||
        die "jq or python3 is required to read $CONFIG_FILE"
}

# json_get <jq-path> -> value on stdout ("" when null/missing)
json_get() {
    local path="$1"
    if command -v jq >/dev/null; then
        jq -r "$path // empty" "$CONFIG_FILE"
    else
        python3 - "$CONFIG_FILE" "$path" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
node = data
for part in sys.argv[2].lstrip('.').split('.'):
    if part.startswith('"') and part.endswith('"'):
        part = part[1:-1]
    if not isinstance(node, dict) or part not in node:
        sys.exit(0)
    node = node[part]
if node is not None:
    print(node)
PY
    fi
}

sha256_of() { sha256sum "$1" | awk '{print $1}'; }

# Look up <iso-name> in the SHA256SUMS file. Prints the hash or nothing.
sums_lookup() {
    local sums_file="$1" iso_name="$2"
    awk -v n="$iso_name" '$2 == "*" n || $2 == n { print $1; exit }' "$sums_file"
}

# Find the first entry matching *-<flavor>-<arch>.iso. Prints "<hash> <name>".
sums_find_flavor() {
    local sums_file="$1" flavor="$2" arch="$3"
    awk -v f="$flavor" -v a="$arch" '
        { name = $2; sub(/^\*/, "", name) }
        name ~ ("^ubuntu-[0-9.]+-" f "-" a "\\.iso$") { print $1, name; exit }
    ' "$sums_file"
}

main() {
    parse_args "$@"
    require_tools
    [[ -f "$CONFIG_FILE" ]] || die "release config not found: $CONFIG_FILE"

    [[ -n "$RELEASE" ]] || RELEASE="$(json_get '.default')"
    [[ -n "$RELEASE" ]] || die "no release requested and no \"default\" in $CONFIG_FILE"

    local base=".releases.\"$RELEASE\""
    local mirror flavor arch iso_pin sha_pin
    mirror="$(json_get "$base.mirror")"
    flavor="$(json_get "$base.flavor")"
    arch="$(json_get "$base.arch")"
    iso_pin="$(json_get "$base.iso")"
    sha_pin="$(json_get "$base.sha256")"

    [[ -n "$mirror" ]] || die "release \"$RELEASE\" is missing \"mirror\" in $CONFIG_FILE"
    [[ "$mirror" == https://* ]] || die "mirror must use https: $mirror"
    [[ -n "$flavor" ]] || flavor="live-server"
    [[ -n "$arch" ]] || arch="amd64"

    mkdir -p "$CACHE_DIR"
    local sums_file="$CACHE_DIR/SHA256SUMS.$RELEASE"

    local iso_name="" expected_sha=""
    if (( OFFLINE )); then
        [[ -n "$iso_pin" && -n "$sha_pin" ]] ||
            [[ -f "$sums_file" ]] ||
            die "--offline needs pinned iso+sha256 in $CONFIG_FILE or a cached SHA256SUMS"
    else
        log "Fetching checksum index: $mirror/SHA256SUMS"
        curl -fsSL --retry 3 -o "$sums_file.tmp" "$mirror/SHA256SUMS" ||
            die "cannot download $mirror/SHA256SUMS"
        mv -f "$sums_file.tmp" "$sums_file"
    fi

    if [[ -n "$iso_pin" ]]; then
        iso_name="$iso_pin"
        if [[ -n "$sha_pin" ]]; then
            expected_sha="$sha_pin"
        elif [[ -f "$sums_file" ]]; then
            expected_sha="$(sums_lookup "$sums_file" "$iso_name")"
        fi
    elif [[ -f "$sums_file" ]]; then
        read -r expected_sha iso_name < <(sums_find_flavor "$sums_file" "$flavor" "$arch") || true
    fi

    [[ -n "$iso_name" ]] || die "could not determine ISO name for release \"$RELEASE\" ($flavor/$arch)"
    [[ -n "$expected_sha" ]] || die "no SHA256 available for $iso_name (not in SHA256SUMS and no pin)"
    [[ "$expected_sha" =~ ^[0-9a-f]{64}$ ]] || die "malformed SHA256 for $iso_name: $expected_sha"

    local iso_path="$CACHE_DIR/$iso_name"

    if [[ -f "$iso_path" ]]; then
        log "Verifying cached ISO: $iso_path"
        if [[ "$(sha256_of "$iso_path")" == "$expected_sha" ]]; then
            log "Checksum OK (cached): $expected_sha"
            printf '%s\n' "$iso_path"
            return 0
        fi
        log "Cached ISO failed verification; it will be re-downloaded."
        mv -f "$iso_path" "$iso_path.corrupt" 2>/dev/null || true
    fi

    (( ! OFFLINE )) || die "--offline: no verified ISO in cache: $iso_path"

    log "Downloading: $mirror/$iso_name"
    log "Destination: $iso_path"
    curl -fL --retry 3 -C - -o "$iso_path.part" "$mirror/$iso_name" ||
        die "download failed: $mirror/$iso_name"

    log "Verifying download..."
    local actual_sha
    actual_sha="$(sha256_of "$iso_path.part")"
    if [[ "$actual_sha" != "$expected_sha" ]]; then
        mv -f "$iso_path.part" "$iso_path.corrupt" 2>/dev/null || true
        die "SHA256 mismatch for $iso_name (expected $expected_sha, got $actual_sha)"
    fi
    mv -f "$iso_path.part" "$iso_path"
    log "Checksum OK: $expected_sha"

    printf '%s\n' "$iso_path"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
