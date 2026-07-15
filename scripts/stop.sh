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

# shellcheck disable=SC1091
. "$EDGE_REPO/scripts/lib/compose.sh"
lisa_build_compose_files "$EDGE_REPO"
FILES=("${LISA_COMPOSE_FILES[@]}")

docker compose --env-file .env "${FILES[@]}" down --remove-orphans
