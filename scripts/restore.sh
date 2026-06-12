#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: sudo $0 /path/to/lisa-edge-backup.tar.gz" >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0 /path/to/backup.tar.gz" >&2
  exit 1
fi

ARCHIVE="$1"
EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

DATA_ROOT="${DATA_ROOT:-/srv/lisa-edge}"
mkdir -p "$DATA_ROOT"

if [ -f .env ]; then
  docker compose --env-file .env -f compose/docker-compose.yml down || true
fi

echo "[LISA] Restoring $ARCHIVE into /"
tar -xzf "$ARCHIVE" -C /

echo "[LISA] Restore finished. Deploying stack..."
"$EDGE_REPO/scripts/deploy.sh"
