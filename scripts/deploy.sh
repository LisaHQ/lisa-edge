#!/usr/bin/env bash
set -euo pipefail
EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

if [ ! -f .env ]; then
  cp .env.example .env
  chmod 0600 .env
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

FILES=(-f compose/docker-compose.yml)
for profile in ${LISA_COMPOSE_SERVICES:-}; do
  case "$profile" in
    otbr|ha|zigbee2mqtt|node-red|vpn-tailscale)
      FILES+=(-f "compose/services/$profile.yml")
      ;;
    "") ;;
    *)
      echo "Unknown LISA_COMPOSE_SERVICES entry: $profile" >&2
      echo "Allowed: otbr homeassistant zigbee2mqtt node-red vpn-tailscale" >&2
      exit 1
      ;;
  esac
done

docker compose --env-file .env "${FILES[@]}" pull || true
docker compose --env-file .env "${FILES[@]}" up -d
"$EDGE_REPO/scripts/healthcheck.sh"
