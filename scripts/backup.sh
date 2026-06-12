#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

if [ ! -f .env ]; then
  echo "Missing .env. Copy .env.example to .env first." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

DATA_ROOT="${DATA_ROOT:-/srv/lisa-edge}"
BACKUP_DIR="${BACKUP_DEST:-$DATA_ROOT/backups}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$BACKUP_DIR/lisa-edge-backup-$TIMESTAMP.tar.gz"
FILES=(-f compose/docker-compose.yml)
for profile in ${LISA_COMPOSE_SERVICES:-}; do
  [ -f "compose/services/$profile.yml" ] && FILES+=(-f "compose/services/$profile.yml")
done

mkdir -p "$BACKUP_DIR"

echo "[LISA] Creating backup: $ARCHIVE"

docker compose --env-file .env "${FILES[@]}" stop || true

tar --warning=no-file-changed \
  --exclude="$DATA_ROOT/docker/volumes/mosquitto/log/*" \
  --exclude="$DATA_ROOT/logs/*" \
  --exclude="$BACKUP_DIR/*" \
  -czf "$ARCHIVE" \
  "$EDGE_REPO/.env" \
  "$EDGE_REPO/compose" \
  "$EDGE_REPO/services" \
  "$DATA_ROOT/data" \
  "$DATA_ROOT/docker" \
  "$DATA_ROOT/state" || status=$?

status="${status:-0}"
if [ "$status" -ne 0 ] && [ "$status" -ne 1 ]; then
  docker compose --env-file .env "${FILES[@]}" up -d || true
  exit "$status"
fi

docker compose --env-file .env "${FILES[@]}" up -d

echo "[LISA] Backup completed: $ARCHIVE"
