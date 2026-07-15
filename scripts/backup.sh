#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

if [ ! -f .env ]; then
  echo "Missing .env. Copy .env.template to .env first." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

# shellcheck disable=SC1091
. "$EDGE_REPO/scripts/lib/compose.sh"
lisa_build_compose_files "$EDGE_REPO"

DATA_ROOT="${DATA_ROOT:-/srv/lisa-edge}"
BACKUP_DIR="${BACKUP_DEST:-$DATA_ROOT/backups}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$BACKUP_DIR/lisa-edge-backup-$TIMESTAMP.tar.gz"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"

case "$BACKUP_DIR" in
  ""|/)
    echo "Refusing to use an unsafe BACKUP_DEST: '$BACKUP_DIR'" >&2
    exit 1
    ;;
  /*) ;;
  *)
    echo "BACKUP_DEST must be an absolute path: '$BACKUP_DIR'" >&2
    exit 1
    ;;
esac

FILES=("${LISA_COMPOSE_FILES[@]}")

mkdir -p "$BACKUP_DIR"
chmod 0700 "$BACKUP_DIR"

BACKUP_PATHS=(
  "$EDGE_REPO/.env"
  "$EDGE_REPO/compose"
  "$EDGE_REPO/config"
  "$DATA_ROOT/data"
  "$DATA_ROOT/docker"
  "$DATA_ROOT/state"
  "$DATA_ROOT/secrets"
)

OTBR_BACKUP_DIR="${OTBR_DATASET_BACKUP_DIR:-$DATA_ROOT/backups/otbr}"
if [ -d "$OTBR_BACKUP_DIR" ]; then
  BACKUP_PATHS+=("$OTBR_BACKUP_DIR")
fi

EXISTING_PATHS=()
for path in "${BACKUP_PATHS[@]}"; do
  [ -e "$path" ] && EXISTING_PATHS+=("$path")
done

echo "[LISA] Creating backup: $ARCHIVE"

STACK_STOPPED=1
restart_stack() {
  if [ "${STACK_STOPPED:-0}" -eq 1 ]; then
    echo "[LISA] Restarting stack after backup..."
    docker compose --env-file .env "${FILES[@]}" up -d || true
  fi
}
trap restart_stack EXIT

docker compose --env-file .env "${FILES[@]}" down --remove-orphans

tar --warning=no-file-changed \
  --exclude='*/docker/volumes/mosquitto/log/*' \
  --exclude='*/logs/*' \
  --exclude='*/lisa-edge-backup-*.tar.gz' \
  -czf "$ARCHIVE" \
  "${EXISTING_PATHS[@]}" || status=$?

status="${status:-0}"
if [ "$status" -ne 0 ] && [ "$status" -ne 1 ]; then
  exit "$status"
fi

docker compose --env-file .env "${FILES[@]}" up -d
STACK_STOPPED=0
trap - EXIT
chmod 0600 "$ARCHIVE"

(
  cd "$BACKUP_DIR"
  sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256"
)
chmod 0600 "$ARCHIVE.sha256"

if command -v jq >/dev/null 2>&1; then
  ARCHIVE_SHA256="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
  GIT_REF="$(git -C "$EDGE_REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  jq -n \
    --arg format_version "1" \
    --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg hostname "$(hostname)" \
    --arg git_ref "$GIT_REF" \
    --arg services "$(lisa_selected_services)" \
    --arg sha256 "$ARCHIVE_SHA256" \
    '{format_version: ($format_version | tonumber), created_at: $created_at, hostname: $hostname, git_ref: $git_ref, services: ($services | split(" ")), contains_secrets: true, sha256: $sha256}' \
    > "$ARCHIVE.manifest.json"
  chmod 0600 "$ARCHIVE.manifest.json"
fi

if [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] && [ "$RETENTION_DAYS" -gt 0 ]; then
  while IFS= read -r -d '' old_archive; do
    rm -f "$old_archive" "$old_archive.sha256" "$old_archive.manifest.json"
  done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'lisa-edge-backup-*.tar.gz' \
    -mtime "+$RETENTION_DAYS" -print0)
fi

echo "[LISA] Backup completed: $ARCHIVE"
