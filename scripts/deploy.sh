#!/usr/bin/env bash
set -euo pipefail
EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

if [ ! -f .env ]; then
  echo "Missing .env. Copy .env.template to .env and review it first." >&2
  exit 1
fi
chmod 0600 .env

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
      echo "Allowed: otbr ha zigbee2mqtt node-red vpn-tailscale" >&2
      exit 1
      ;;
  esac
done

docker compose --env-file .env "${FILES[@]}" pull || true
"$EDGE_REPO/scripts/prepare-mqtt.sh"
docker compose --env-file .env "${FILES[@]}" up -d --remove-orphans --force-recreate mosquitto
docker compose --env-file .env "${FILES[@]}" up -d --remove-orphans
"$EDGE_REPO/scripts/healthcheck.sh"

if echo "${LISA_COMPOSE_SERVICES:-}" | grep -qw otbr; then
  "$EDGE_REPO/scripts/otbr-init-or-restore.sh"
fi
