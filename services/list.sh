#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/registry.sh"

printf '%-16s %-9s %-16s %s\n' 'SERVICE' 'DEFAULT' 'DEPENDENCIES' 'PURPOSE'
for service in $LISA_ALL_SERVICES; do
  default=no
  lisa_service_is_default "$service" && default=yes
  dependencies="$(lisa_service_dependencies "$service")"
  printf '%-16s %-9s %-16s %s\n' \
    "$service" "$default" "${dependencies:--}" "$(lisa_service_description "$service")"
done

cat <<'EOF'

Aliases accepted by the command interface:
  home-assistant -> ha
  matter-server -> matter
  tailscale -> vpn-tailscale
EOF
