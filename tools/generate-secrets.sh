#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  tools/generate-secrets.sh [option]

Options:
  --all              Generate common LISA Edge secrets
  --password         Generate one random password
  --hash             Generate Ubuntu SHA-512 password hash
  --jwt              Generate JWT secret
  --api              Generate API secret
  --cookie           Generate cookie secret
  --wireguard        Generate WireGuard keypair if wg is installed
  -h, --help         Show help

Default:
  --all
EOF
}

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $cmd"
        exit 1
    fi
}

generate_password() {
    openssl rand -base64 24
}

generate_hex() {
    local bytes="$1"
    openssl rand -hex "$bytes"
}

generate_password_hash() {
    echo "Enter password to hash:"
    openssl passwd -6
}

generate_wireguard_keypair() {
    if ! command -v wg >/dev/null 2>&1; then
        echo "WireGuard tools not found. Skipping WireGuard key generation."
        return
    fi

    local private_key
    local public_key

    private_key="$(wg genkey)"
    public_key="$(printf '%s' "$private_key" | wg pubkey)"

    echo "WIREGUARD_PRIVATE_KEY=$private_key"
    echo "WIREGUARD_PUBLIC_KEY=$public_key"
}

main() {
    local mode="${1:---all}"

    require_cmd openssl

    case "$mode" in
        --all)
            echo "RANDOM_PASSWORD=$(generate_password)"
            echo "JWT_SECRET=$(generate_hex 64)"
            echo "API_SECRET=$(generate_hex 32)"
            echo "COOKIE_SECRET=$(generate_hex 32)"
            generate_wireguard_keypair
            echo
            echo "Ubuntu password hash:"
            generate_password_hash
            ;;
        --password)
            generate_password
            ;;
        --hash)
            generate_password_hash
            ;;
        --jwt)
            generate_hex 64
            ;;
        --api)
            generate_hex 32
            ;;
        --cookie)
            generate_hex 32
            ;;
        --wireguard)
            generate_wireguard_keypair
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "ERROR: unknown option: $mode"
            usage
            exit 1
            ;;
    esac
}

main "$@"
