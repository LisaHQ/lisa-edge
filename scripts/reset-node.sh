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

# shellcheck disable=SC1091
. "$EDGE_REPO/scripts/lib/paths.sh"
lisa_validate_persistent_path DATA_ROOT "$DATA_ROOT"

read -r -p "This will stop containers and delete LISA Edge data under $DATA_ROOT. Type RESET to continue: " answer
if [ "$answer" != "RESET" ]; then
  echo "Aborted."
  exit 1
fi

# shellcheck disable=SC1091
. "$EDGE_REPO/scripts/lib/compose.sh"
lisa_build_compose_files "$EDGE_REPO"
FILES=("${LISA_COMPOSE_FILES[@]}")

docker compose --env-file .env "${FILES[@]}" down -v --remove-orphans || true
rm -rf "$DATA_ROOT/docker/volumes" "$DATA_ROOT/data" "$DATA_ROOT/state" "$DATA_ROOT/logs"
"$EDGE_REPO/bootstrap/phases/30-directories.sh"
"$EDGE_REPO/bootstrap/phases/40-core-service-prep.sh"
"$EDGE_REPO/scripts/deploy.sh"
