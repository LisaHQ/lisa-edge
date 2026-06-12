#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

if [ ! -f .env ]; then
  echo "Missing .env. Nothing to reset." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

DATA_ROOT="${DATA_ROOT:-/srv/lisa-edge}"

read -r -p "This will stop containers and delete LISA Edge data under $DATA_ROOT. Type RESET to continue: " answer
if [ "$answer" != "RESET" ]; then
  echo "Aborted."
  exit 1
fi

docker compose --env-file .env -f compose/docker-compose.yml down -v || true
rm -rf "$DATA_ROOT/docker/volumes" "$DATA_ROOT/data" "$DATA_ROOT/state" "$DATA_ROOT/logs"
"$EDGE_REPO/bootstrap/phases/30-directories.sh"
"$EDGE_REPO/bootstrap/phases/40-mosquitto-defaults.sh"
"$EDGE_REPO/scripts/deploy.sh"
