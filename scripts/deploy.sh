#!/usr/bin/env bash
set -euo pipefail
EDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_DIR"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

FILES=(-f compose/docker-compose.yml)
if [[ " ${LISA_COMPOSE_PROFILES:-} " == *" otbr "* ]]; then
  FILES+=(-f compose/profiles/otbr.yml)
fi

COMPOSE_PROFILES="${LISA_COMPOSE_PROFILES:-}" docker compose --env-file .env "${FILES[@]}" pull || true
COMPOSE_PROFILES="${LISA_COMPOSE_PROFILES:-}" docker compose --env-file .env "${FILES[@]}" up -d
"$EDGE_DIR/scripts/healthcheck.sh"
