#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/compose.sh"

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
# With the default configuration, selecting matter also layers its BLE
# compose slice (MATTER_BLUETOOTH_ADAPTER defaults to adapter 0).
unset MATTER_BLUETOOTH_ADAPTER MATTER_PRIMARY_INTERFACE || true
lisa_build_compose_files "$REPO_ROOT"
[ "${#LISA_COMPOSE_FILES[@]}" -eq 20 ] || {
  echo "Expected core plus eight service Compose files plus the Matter BLE slice." >&2
  exit 1
}

MATTER_BLUETOOTH_ADAPTER=none
MATTER_PRIMARY_INTERFACE=enp1s0
lisa_build_compose_files "$REPO_ROOT"
[ "${#LISA_COMPOSE_FILES[@]}" -eq 20 ] || {
  echo "Expected the primary-interface slice to replace the BLE slice in the count." >&2
  exit 1
}
printf '%s\n' "${LISA_COMPOSE_FILES[@]}" | grep -q 'compose.primary-interface.yml' || {
  echo "Expected the primary-interface slice to be included." >&2
  exit 1
}

echo "Service-selection tests passed."
