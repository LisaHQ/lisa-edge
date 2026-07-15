#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/compose.sh"

LISA_COMPOSE_SERVICES="zigbee2mqtt"
if lisa_validate_services >/dev/null 2>&1; then
  echo "Expected zigbee2mqtt without mqtt to fail dependency validation." >&2
  exit 1
fi

LISA_COMPOSE_SERVICES="mqtt zigbee2mqtt"
lisa_validate_services
lisa_build_compose_files "$REPO_ROOT"

LISA_COMPOSE_SERVICES="all"
lisa_validate_services
lisa_build_compose_files "$REPO_ROOT"
[ "${#LISA_COMPOSE_FILES[@]}" -eq 16 ] || {
  echo "Expected core plus seven service Compose files." >&2
  exit 1
}

echo "Service-selection tests passed."
