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

# shellcheck disable=SC1091
. "$EDGE_REPO/scripts/lib/compose.sh"
lisa_build_compose_files "$EDGE_REPO"
FILES=("${LISA_COMPOSE_FILES[@]}")

docker compose --env-file .env "${FILES[@]}" pull || true
if lisa_has_service mqtt; then
  "$EDGE_REPO/scripts/prepare-mqtt.sh"
  docker compose --env-file .env "${FILES[@]}" up -d --remove-orphans --force-recreate mosquitto
fi
docker compose --env-file .env "${FILES[@]}" up -d --remove-orphans
"$EDGE_REPO/scripts/healthcheck.sh"

if lisa_has_service otbr; then
  "$EDGE_REPO/scripts/otbr-init-or-restore.sh"
fi
