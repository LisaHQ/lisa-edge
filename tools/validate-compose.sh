#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
  tools/validate-compose.sh services/mqtt/compose.yml
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

compose_paths_for_selection() {
    local index
    LISA_COMPOSE_PATHS=()
    lisa_build_compose_files "$REPO_ROOT"
    for ((index = 1; index < ${#LISA_COMPOSE_FILES[@]}; index += 2)); do
        LISA_COMPOSE_PATHS+=("${LISA_COMPOSE_FILES[$index]}")
    done
}

main() {
    local target="${1:-}"
    local failed=0
    local service dependencies

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

    # shellcheck disable=SC1091
    . "$REPO_ROOT/lib/compose.sh"

    if ! validate_stack "canonical base" "$REPO_ROOT/ops/deploy/compose.yml"; then
        failed=1
    fi

    for service in $LISA_ALL_SERVICES; do
        dependencies="$(lisa_service_dependencies "$service")"
        # Read by compose_paths_for_selection/lib functions, not directly here.
        # shellcheck disable=SC2034
        LISA_COMPOSE_SERVICES="${dependencies:+$dependencies }$service"
        compose_paths_for_selection
        if ! validate_stack "$service" "${LISA_COMPOSE_PATHS[@]}"; then
            failed=1
        fi
    done

    # The matter service composes optional slices depending on environment
    # variables; validate the full combination explicitly (BLE enabled and a
    # pinned primary interface) since the per-service loop above only covers
    # the defaults.
    if ! MATTER_PRIMARY_INTERFACE=eth0 validate_stack \
        "matter (BLE + primary-interface slices)" \
        "$REPO_ROOT/ops/deploy/compose.yml" \
        "$REPO_ROOT/services/matter-server/compose.yml" \
        "$REPO_ROOT/services/matter-server/compose.ble.yml" \
        "$REPO_ROOT/services/matter-server/compose.primary-interface.yml"; then
        failed=1
    fi
    if ! MATTER_BLUETOOTH_ADAPTER=none validate_stack \
        "matter (BLE disabled)" \
        "$REPO_ROOT/ops/deploy/compose.yml" \
        "$REPO_ROOT/services/matter-server/compose.yml"; then
        failed=1
    fi

    # shellcheck disable=SC2034
    LISA_COMPOSE_SERVICES=all
    compose_paths_for_selection
    if ! validate_stack "all registered services" "${LISA_COMPOSE_PATHS[@]}"; then
        failed=1
    fi

    echo
    if [[ "$failed" -eq 0 ]]; then
        echo "All canonical Compose files validated successfully."
    else
        echo "One or more Compose configurations failed validation."
        exit 1
    fi
}

main "$@"
