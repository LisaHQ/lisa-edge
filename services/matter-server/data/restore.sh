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
ARCHIVE_FILE="${1:-${MATTER_DATA_LATEST:-$BACKUP_DIR/latest.matter-data.tar.gz}}"

# shellcheck disable=SC1091
. "$EDGE_REPO/lib/paths.sh"
# shellcheck disable=SC1091
. "$EDGE_REPO/services/matter-server/data/lib.sh"
lisa_validate_persistent_path MATTER_DATA_DIR "$MATTER_DATA_DIR"
lisa_validate_persistent_path MATTER_DATA_BACKUP_DIR "$BACKUP_DIR"

if [ ! -f "$ARCHIVE_FILE" ]; then
  echo "ERROR: Matter data archive not found: $ARCHIVE_FILE" >&2
  exit 1
fi

if ! matter_data_archive_is_valid "$ARCHIVE_FILE"; then
  echo "ERROR: Matter data archive is not a readable tar.gz with safe relative members: $ARCHIVE_FILE" >&2
  exit 1
fi

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
  echo "Stopping lisa-matter before replacing its fabric data..."
  trap restart_matter EXIT
  docker stop lisa-matter >/dev/null
fi

# Safety snapshot: never destroy the only copy of a live fabric. The container
# is already stopped here, so the snapshot is consistent.
if matter_data_dir_has_state "$MATTER_DATA_DIR"; then
  mkdir -p "$BACKUP_DIR"
  chmod 0700 "$BACKUP_DIR"
  SAFETY_OUT="$BACKUP_DIR/matter-data-$(date -u +%Y%m%dT%H%M%SZ)-pre-restore.tar.gz"
  tar -C "$MATTER_DATA_DIR" -czf "$SAFETY_OUT" .
  chmod 0600 "$SAFETY_OUT"
  echo "Current fabric data preserved as: $SAFETY_OUT"
fi

mkdir -p "$MATTER_DATA_DIR"
find "$MATTER_DATA_DIR" -mindepth 1 -delete
tar -C "$MATTER_DATA_DIR" -xzf "$ARCHIVE_FILE"

if [ "$WAS_RUNNING" -eq 1 ]; then
  restart_matter
  WAS_RUNNING=0
  trap - EXIT
fi

echo "Matter fabric data restored from: $ARCHIVE_FILE"
echo "Verify with: sudo ./lisa-edge health, then confirm Matter devices are reachable in Home Assistant."
