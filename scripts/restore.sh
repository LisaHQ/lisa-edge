#!/usr/bin/env bash
set -euo pipefail

NO_DEPLOY=0
if [ "${1:-}" = "--no-deploy" ]; then
  NO_DEPLOY=1
  shift
fi

if [ $# -ne 1 ]; then
  echo "Usage: sudo $0 [--no-deploy] /path/to/lisa-edge-backup.tar.gz" >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0 /path/to/backup.tar.gz" >&2
  exit 1
fi

ARCHIVE="$1"
EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

if [ ! -f "$ARCHIVE" ]; then
  echo "Backup archive not found: $ARCHIVE" >&2
  exit 1
fi

if ! tar -tzf "$ARCHIVE" >/dev/null; then
  echo "Backup archive is not a readable tar.gz file: $ARCHIVE" >&2
  exit 1
fi

if [ -f "$ARCHIVE.sha256" ]; then
  echo "[LISA] Verifying backup checksum..."
  (cd "$(dirname "$ARCHIVE")" && sha256sum -c "$(basename "$ARCHIVE.sha256")")
fi

if tar -tzf "$ARCHIVE" | awk '
  /^\// { unsafe=1 }
  /(^|\/)\.\.($|\/)/ { unsafe=1 }
  END { exit unsafe ? 0 : 1 }
'; then
  echo "Backup archive contains an unsafe absolute or parent path." >&2
  exit 1
fi

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

DATA_ROOT="${DATA_ROOT:-/srv/lisa-edge}"
mkdir -p "$DATA_ROOT"

if [ -f .env ]; then
  # shellcheck disable=SC1091
  . "$EDGE_REPO/scripts/lib/compose.sh"
  lisa_build_compose_files "$EDGE_REPO"
  FILES=("${LISA_COMPOSE_FILES[@]}")
  docker compose --env-file .env "${FILES[@]}" down --remove-orphans || true
fi

echo "[LISA] Restoring $ARCHIVE into /"
tar -xzf "$ARCHIVE" -C /

if [ "$NO_DEPLOY" -eq 1 ]; then
  echo "[LISA] Restore finished. Deployment was intentionally skipped."
else
  echo "[LISA] Restore finished. Deploying stack..."
  "$EDGE_REPO/scripts/deploy.sh"
fi
