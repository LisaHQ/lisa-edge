#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

COMPOSE_DIR="${COMPOSE_DIR:-$REPO_ROOT/compose}"
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env}"

usage() {
    cat <<'EOF'
Usage:
  tools/validate-compose.sh [compose-file]

Examples:
  tools/validate-compose.sh
  tools/validate-compose.sh compose/mqtt/compose.yml
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

validate_file() {
    local file="$1"
    local env_args=()

    [[ -f "$file" ]] || die "compose file not found: $file"

    if [[ -f "$ENV_FILE" ]]; then
        env_args=(--env-file "$ENV_FILE")
    fi

    echo
    echo "Checking:"
    echo "  $file"

    if docker compose "${env_args[@]}" -f "$file" config >/dev/null; then
        echo "  OK"
        return 0
    fi

    echo "  FAILED"
    return 1
}

main() {
    local target="${1:-}"
    local failed=0
    local found=0

    if [[ "$target" == "-h" || "$target" == "--help" ]]; then
        usage
        exit 0
    fi

    command -v docker >/dev/null 2>&1 || die "docker not found"
    docker compose version >/dev/null 2>&1 || die "docker compose is not available"

    if [[ -n "$target" ]]; then
        validate_file "$target"
        exit $?
    fi

    [[ -d "$COMPOSE_DIR" ]] || die "compose directory not found: $COMPOSE_DIR"

    while IFS= read -r file; do
        found=1
        if ! validate_file "$file"; then
            failed=1
        fi
    done < <(
        find "$COMPOSE_DIR" \
            -type f \
            \( -name "compose.yml" -o -name "compose.yaml" -o -name "docker-compose.yml" -o -name "docker-compose.yaml" \) \
            | sort
    )

    echo

    [[ "$found" -eq 1 ]] || die "no compose files found in $COMPOSE_DIR"

    if [[ "$failed" -eq 0 ]]; then
        echo "All compose files validated successfully."
    else
        echo "One or more compose files failed validation."
        exit 1
    fi
}

main "$@"
