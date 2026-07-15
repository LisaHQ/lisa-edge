#!/usr/bin/env bash
set -euo pipefail

NO_DEPLOY=1
ALLOW_MISSING_CHECKSUM=0
ARCHIVE=""
PYTHON_BIN="${PYTHON_BIN:-python3}"
RESTORE_TARGET_ROOT="${LISA_RESTORE_TARGET_ROOT:-/}"

usage() {
  echo "Usage: sudo $0 [--deploy|--no-deploy] [--allow-missing-checksum] /path/to/lisa-edge-backup.tar.gz" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-deploy) NO_DEPLOY=1 ;;
    --deploy) NO_DEPLOY=0 ;;
    --allow-missing-checksum) ALLOW_MISSING_CHECKSUM=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *)
      [ -z "$ARCHIVE" ] || { echo "Only one backup archive may be specified." >&2; exit 1; }
      ARCHIVE="$1"
      ;;
  esac
  shift
done

[ -n "$ARCHIVE" ] || { usage; exit 1; }

if [ "$RESTORE_TARGET_ROOT" = "/" ] && [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0 /path/to/backup.tar.gz" >&2
  exit 1
fi

ARCHIVE="$(readlink -f "$ARCHIVE")"
[ -f "$ARCHIVE" ] || { echo "Backup archive not found: $ARCHIVE" >&2; exit 1; }

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

# shellcheck disable=SC1091
. "$EDGE_REPO/scripts/lib/backup.sh"
# shellcheck disable=SC1091
. "$EDGE_REPO/scripts/lib/paths.sh"

command -v "$PYTHON_BIN" >/dev/null 2>&1 || {
  echo "$PYTHON_BIN is required for safe backup validation." >&2
  exit 1
}

if [ "$RESTORE_TARGET_ROOT" != "/" ]; then
  [ "${LISA_EDGE_TESTING:-0}" = "1" ] || {
    echo "LISA_RESTORE_TARGET_ROOT is restricted to the integration test harness." >&2
    exit 1
  }
  [ "$NO_DEPLOY" -eq 1 ] || { echo "Test-target restores cannot deploy." >&2; exit 1; }
  case "$RESTORE_TARGET_ROOT" in /tmp/*) ;; *) echo "Test restore target must be below /tmp." >&2; exit 1 ;; esac
  mkdir -p "$RESTORE_TARGET_ROOT"
  RESTORE_TARGET_ROOT="$(readlink -f "$RESTORE_TARGET_ROOT")"
  [ "$RESTORE_TARGET_ROOT" != "/" ] || { echo "Refusing unsafe test restore target." >&2; exit 1; }
fi

lisa_verify_backup_checksum "$ARCHIVE" "$ALLOW_MISSING_CHECKSUM"

STAGING_ROOT="$(mktemp -d /tmp/lisa-edge-restore.XXXXXX)"
ARCHIVED_ENV="$STAGING_ROOT/validated.env"
EXTRACT_ROOT="$STAGING_ROOT/root"
cleanup() { rm -rf "$STAGING_ROOT"; }
trap cleanup EXIT

REPO_MEMBER="${EDGE_REPO#/}"
ENV_MEMBER="$REPO_MEMBER/.env"
VALIDATOR="$EDGE_REPO/scripts/lib/validate_backup.py"

echo "[LISA] Inspecting archive structure and environment..."
"$PYTHON_BIN" "$VALIDATOR" \
  --archive "$ARCHIVE" \
  --env-member "$ENV_MEMBER" \
  --env-output "$ARCHIVED_ENV" \
  --env-template "$EDGE_REPO/.env.template"

RESTORED_DATA_ROOT="$(lisa_read_validated_env_value "$ARCHIVED_ENV" DATA_ROOT /srv/lisa-edge)"
RESTORED_OTBR_DIR="$(lisa_read_validated_env_value \
  "$ARCHIVED_ENV" OTBR_DATASET_BACKUP_DIR "$RESTORED_DATA_ROOT/backups/otbr")"

validate_restore_root() {
  local path="$1"
  lisa_validate_persistent_path "Archived persistent-data path" "$path"
}

for safe_path in "$RESTORED_DATA_ROOT" "$RESTORED_OTBR_DIR"; do
  validate_restore_root "$safe_path"
done

ALLOW_ARGS=(
  --allow "$REPO_MEMBER/.env"
  --allow "$REPO_MEMBER/compose"
  --allow "$REPO_MEMBER/config"
  --allow "${RESTORED_DATA_ROOT#/}/data"
  --allow "${RESTORED_DATA_ROOT#/}/docker"
  --allow "${RESTORED_DATA_ROOT#/}/state"
  --allow "${RESTORED_DATA_ROOT#/}/secrets"
  --allow "${RESTORED_OTBR_DIR#/}"
)

echo "[LISA] Validating restore allowlist and extracting into protected staging..."
"$PYTHON_BIN" "$VALIDATOR" \
  --archive "$ARCHIVE" \
  --env-member "$ENV_MEMBER" \
  --env-output "$ARCHIVED_ENV" \
  --env-template "$EDGE_REPO/.env.template" \
  --extract-root "$EXTRACT_ROOT" \
  "${ALLOW_ARGS[@]}"

# Stop the currently configured stack before replacing persistent data.
if [ "$RESTORE_TARGET_ROOT" = "/" ] && [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
  # shellcheck disable=SC1091
  . "$EDGE_REPO/scripts/lib/compose.sh"
  lisa_build_compose_files "$EDGE_REPO"
  FILES=("${LISA_COMPOSE_FILES[@]}")
  docker compose --env-file .env "${FILES[@]}" down --remove-orphans || true
fi

echo "[LISA] Restoring validated files into $RESTORE_TARGET_ROOT"
RESTORE_MEMBERS=(
  "$REPO_MEMBER/.env"
  "${RESTORED_DATA_ROOT#/}/data"
  "${RESTORED_DATA_ROOT#/}/docker"
  "${RESTORED_DATA_ROOT#/}/state"
  "${RESTORED_DATA_ROOT#/}/secrets"
  "${RESTORED_OTBR_DIR#/}"
)
for member in "${RESTORE_MEMBERS[@]}"; do
  source_path="$EXTRACT_ROOT/$member"
  if [ "$RESTORE_TARGET_ROOT" = "/" ]; then
    target_path="/$member"
  else
    target_path="$RESTORE_TARGET_ROOT/$member"
  fi
  [ -e "$source_path" ] || continue
  if [ -d "$source_path" ]; then
    mkdir -p "$target_path"
    cp -a "$source_path/." "$target_path/"
  else
    mkdir -p "$(dirname "$target_path")"
    cp -a "$source_path" "$target_path"
  fi
done

if [ "$NO_DEPLOY" -eq 1 ]; then
  echo "[LISA] Restore finished. Deployment was intentionally skipped by default."
  echo "[LISA] Review .env, then run scripts/deploy.sh or repeat restore with --deploy."
else
  echo "[LISA] Restore finished. Deploying stack..."
  "$EDGE_REPO/scripts/deploy.sh"
fi
