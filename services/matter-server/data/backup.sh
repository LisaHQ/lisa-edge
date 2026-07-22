#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$EDGE_REPO"

set -a
source ./.env
set +a

DATA_ROOT="${DATA_ROOT:-/srv/lisa-edge}"
MATTER_DATA_DIR="$DATA_ROOT/docker/volumes/matter-server"
BACKUP_DIR="${MATTER_DATA_BACKUP_DIR:-$DATA_ROOT/backups/matter}"
# shellcheck disable=SC1091
. "$EDGE_REPO/lib/paths.sh"
# shellcheck disable=SC1091
. "$EDGE_REPO/services/matter-server/data/lib.sh"
lisa_validate_persistent_path MATTER_DATA_BACKUP_DIR "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
chmod 0700 "$BACKUP_DIR"

# Optional description appended to the backup filename:
#   backup.sh [description]
DESCRIPTION_RAW="${1:-}"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
BASE_NAME="matter-data-$TS"
# Reserve room for the base name, the '-' separator and the '.tar.gz' extension.
DESCRIPTION_MAX=$((MATTER_FILENAME_MAX_BYTES - ${#BASE_NAME} - 1 - 7))
DESCRIPTION="$(matter_sanitize_backup_description "$DESCRIPTION_RAW" "$DESCRIPTION_MAX")"
OUT="$BACKUP_DIR/$BASE_NAME${DESCRIPTION:+-$DESCRIPTION}.tar.gz"
LATEST="$BACKUP_DIR/latest.matter-data.tar.gz"
RETENTION_DAYS="${MATTER_DATA_RETENTION_DAYS:-30}"

if ! matter_data_dir_has_state "$MATTER_DATA_DIR"; then
  echo "ERROR: No Matter fabric data to back up under $MATTER_DATA_DIR." >&2
  echo "Deploy the Matter service and commission at least the controller fabric first." >&2
  exit 1
fi

# The fabric store is a set of small files written by the running server.
# Stop the container for the few seconds the snapshot takes so the archive is
# guaranteed consistent; restart it afterwards only if it was running.
WAS_RUNNING=0
if command -v docker >/dev/null 2>&1 &&
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qx lisa-matter; then
  WAS_RUNNING=1
fi
restart_matter() {
  if [ "${WAS_RUNNING:-0}" -eq 1 ]; then
    docker start lisa-matter >/dev/null 2>&1 || \
      echo "WARNING: Could not restart lisa-matter; start it with: docker start lisa-matter" >&2
  fi
}
if [ "$WAS_RUNNING" -eq 1 ]; then
  echo "Stopping lisa-matter for a consistent snapshot..."
  trap restart_matter EXIT
  docker stop lisa-matter >/dev/null
fi

tar -C "$MATTER_DATA_DIR" -czf "$OUT" .
chmod 0600 "$OUT"
ln -sfn "$(basename "$OUT")" "$LATEST"

if [ "$WAS_RUNNING" -eq 1 ]; then
  restart_matter
  WAS_RUNNING=0
  trap - EXIT
fi

if [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] && [ "$RETENTION_DAYS" -gt 0 ]; then
  find "$BACKUP_DIR" -maxdepth 1 -type f -name 'matter-data-*.tar.gz' \
    -mtime "+$RETENTION_DAYS" -delete
fi

echo "Matter fabric data backed up to: $OUT"
