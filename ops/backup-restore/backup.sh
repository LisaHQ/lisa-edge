#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
. "$EDGE_REPO/lib/compose.sh"
lisa_build_compose_files "$EDGE_REPO"

DATA_ROOT="${DATA_ROOT:-/srv/lisa-edge}"
BACKUP_DIR="${BACKUP_DEST:-$DATA_ROOT/backups}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="$BACKUP_DIR/lisa-edge-backup-$TIMESTAMP.tar.gz"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"

# shellcheck disable=SC1091
. "$EDGE_REPO/lib/paths.sh"
lisa_validate_persistent_path DATA_ROOT "$DATA_ROOT"
lisa_validate_persistent_path BACKUP_DEST "$BACKUP_DIR"

BACKUP_REQUIRE_MOUNT="${BACKUP_REQUIRE_MOUNT:-0}"
case "$BACKUP_REQUIRE_MOUNT" in 0|1) ;; *) echo "BACKUP_REQUIRE_MOUNT must be 0 or 1." >&2; exit 1 ;; esac
if [ "$BACKUP_REQUIRE_MOUNT" = "1" ]; then
  echo "[LISA] Verifying mounted backup destination..."
  lisa_verify_mounted_destination "$BACKUP_DIR" "${BACKUP_EXPECTED_MOUNT_SOURCE:-}"
else
  mkdir -p "$BACKUP_DIR"
fi

FILES=("${LISA_COMPOSE_FILES[@]}")

chmod 0700 "$BACKUP_DIR"

OTBR_BACKUP_DIR="${OTBR_DATASET_BACKUP_DIR:-$DATA_ROOT/backups/otbr}"
BACKUP_STAGING="$(mktemp -d)"
STAGING_ITEMS=(.env)
DATA_ITEMS=()
cp "$EDGE_REPO/.env" "$BACKUP_STAGING/.env"
chmod 0600 "$BACKUP_STAGING/.env"

for item in data docker state secrets; do
  [ -e "$DATA_ROOT/$item" ] && DATA_ITEMS+=("$item")
done

if [ -d "$OTBR_BACKUP_DIR" ]; then
  mkdir -p "$BACKUP_STAGING/otbr"
  cp -a "$OTBR_BACKUP_DIR/." "$BACKUP_STAGING/otbr/"
  STAGING_ITEMS+=(otbr)
fi

echo "[LISA] Creating backup: $ARCHIVE"

STACK_STOPPED=1
restart_stack() {
  if [ "${STACK_STOPPED:-0}" -eq 1 ]; then
    echo "[LISA] Restarting stack after backup..."
    docker compose --env-file .env "${FILES[@]}" up -d || true
  fi
  rm -rf "$BACKUP_STAGING"
}
trap restart_stack EXIT

docker compose --env-file .env "${FILES[@]}" down --remove-orphans

TAR_INPUTS=(-C "$BACKUP_STAGING" "${STAGING_ITEMS[@]}")
if [ "${#DATA_ITEMS[@]}" -gt 0 ]; then
  TAR_INPUTS+=(-C "$DATA_ROOT" "${DATA_ITEMS[@]}")
fi

tar --warning=no-file-changed \
  --exclude='docker/volumes/mosquitto/log/*' \
  --exclude='*/logs/*' \
  --exclude='*/lisa-edge-backup-*.tar.gz' \
  -czf "$ARCHIVE" \
  "${TAR_INPUTS[@]}" || status=$?

status="${status:-0}"
if [ "$status" -ne 0 ] && [ "$status" -ne 1 ]; then
  exit "$status"
fi

docker compose --env-file .env "${FILES[@]}" up -d
STACK_STOPPED=0
rm -rf "$BACKUP_STAGING"
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
    --arg format_version "3" \
    --arg archive_layout "logical-v3" \
    --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg hostname "$(hostname)" \
    --arg git_ref "$GIT_REF" \
    --arg services "$(lisa_selected_services)" \
    --arg repo_root "$EDGE_REPO" \
    --arg data_root "$DATA_ROOT" \
    --arg otbr_backup_dir "$OTBR_BACKUP_DIR" \
    --arg sha256 "$ARCHIVE_SHA256" \
    '{format_version: ($format_version | tonumber), archive_layout: $archive_layout, created_at: $created_at, hostname: $hostname, git_ref: $git_ref, services: ($services | split(" ")), repo_root: $repo_root, data_root: $data_root, otbr_backup_dir: $otbr_backup_dir, contains_secrets: true, sha256: $sha256}' \
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
