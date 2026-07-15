#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

COMPOSE_DIR="${COMPOSE_DIR:-$REPO_ROOT/compose}"
if [[ -n "${ENV_FILE:-}" ]]; then
    ENV_FILE="$ENV_FILE"
elif [[ -f "$REPO_ROOT/.env" ]]; then
    ENV_FILE="$REPO_ROOT/.env"
else
    ENV_FILE="$REPO_ROOT/.env.template"
fi

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

validate_stack() {
    local label="$1"
    shift
    local env_args=()
    local compose_args=()
    local file

    for file in "$@"; do
        [[ -f "$file" ]] || die "compose file not found: $file"
        compose_args+=(-f "$file")
    done

    if [[ -f "$ENV_FILE" ]]; then
        env_args=(--env-file "$ENV_FILE")
    fi

    echo
    echo "Checking:"
    echo "  $label"

    if docker compose "${env_args[@]}" "${compose_args[@]}" config >/dev/null; then
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
        validate_stack "$target" "$target"
        exit $?
    fi

    [[ -d "$COMPOSE_DIR" ]] || die "compose directory not found: $COMPOSE_DIR"

    local core="$COMPOSE_DIR/docker-compose.yml"
    local overlays=()
    local file

    [[ -f "$core" ]] || die "core compose file not found: $core"
    found=1

    if ! validate_stack "core" "$core"; then
        failed=1
    fi

    while IFS= read -r file; do
        overlays+=("$file")
        if ! validate_stack "core + $(basename "$file")" "$core" "$file"; then
            failed=1
        fi
    done < <(find "$COMPOSE_DIR/services" -maxdepth 1 -type f -name '*.yml' | sort)

    if [[ "${#overlays[@]}" -gt 0 ]]; then
        if ! validate_stack "core + all optional services" "$core" "${overlays[@]}"; then
            failed=1
        fi
    fi

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
