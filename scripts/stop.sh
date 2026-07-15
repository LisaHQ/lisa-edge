#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

if [ ! -f .env ]; then
  exit 0
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

FILES=(-f compose/docker-compose.yml)
for profile in ${LISA_COMPOSE_SERVICES:-}; do
  [ -f "compose/services/$profile.yml" ] && FILES+=(-f "compose/services/$profile.yml")
done

docker compose --env-file .env "${FILES[@]}" down --remove-orphans
