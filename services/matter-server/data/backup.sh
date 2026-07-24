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

usage() {
  cat <<'EOF'
Usage: services/matter-server/data/backup.sh [--label <label>]

Create a consistent Matter fabric data archive with checksum and metadata
sidecars under MATTER_DATA_BACKUP_DIR.
EOF
}

LABEL_RAW=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --label)
      [ "$#" -ge 2 ] || { echo "ERROR: --label requires a value." >&2; exit 2; }
      LABEL_RAW="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "ERROR: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

TS="$(date -u +%Y%m%dT%H%M%SZ)"
BASE_NAME="matter-data-$TS"
# Reserve room for the base name, the '-' separator and the '.tar.gz.sha256'
# extension (the longest sidecar suffix).
LABEL_MAX=$((MATTER_FILENAME_MAX_BYTES - ${#BASE_NAME} - 1 - 14))
LABEL="$(matter_sanitize_backup_description "$LABEL_RAW" "$LABEL_MAX")"
OUT="$BACKUP_DIR/$BASE_NAME${LABEL:+-$LABEL}.tar.gz"
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
  grep -qx lisa-matter <<<"$(docker ps --format '{{.Names}}' 2>/dev/null || true)"; then
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

# Stage in the destination directory, then rename: a power loss mid-write
# must never leave a truncated archive behind the latest symlink.
TMP_OUT="$(umask 077 && mktemp "$BACKUP_DIR/.matter-data.XXXXXX")"
cleanup_tmp() { rm -f -- "$TMP_OUT" 2>/dev/null || true; }
trap 'cleanup_tmp; restart_matter' EXIT
tar -C "$MATTER_DATA_DIR" -czf "$TMP_OUT" .
chmod 0600 "$TMP_OUT"
mv -- "$TMP_OUT" "$OUT"
trap restart_matter EXIT
matter_data_write_archive_sidecars "$OUT" "$LABEL"
ln -sfn "$(basename "$OUT")" "$LATEST"

restart_matter
WAS_RUNNING=0
trap - EXIT

if [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] && [ "$RETENTION_DAYS" -gt 0 ]; then
  find "$BACKUP_DIR" -maxdepth 1 -type f \
    \( -name 'matter-data-*.tar.gz' -o -name 'matter-data-*.tar.gz.sha256' \
       -o -name 'matter-data-*.tar.gz.meta' \) \
    -mtime "+$RETENTION_DAYS" -delete
fi

echo "Matter fabric data backed up to: $OUT"
