#!/usr/bin/env bash
set -euo pipefail
EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

PULL_POLICY=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --pull) PULL_POLICY=always ;;
    --offline) PULL_POLICY=never ;;
    -h|--help)
      echo "Usage: $0 [--pull|--offline]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ ! -f .env ]; then
  echo "Missing .env. Copy .env.template to .env and review it first." >&2
  exit 1
fi
chmod 0600 .env

set -a
# shellcheck disable=SC1091
. ./.env
set +a

# shellcheck disable=SC1091
. "$EDGE_REPO/scripts/lib/paths.sh"
lisa_validate_persistent_path DATA_ROOT "${DATA_ROOT:-/srv/lisa-edge}"

PULL_POLICY="${PULL_POLICY:-${LISA_PULL_POLICY:-missing}}"
case "$PULL_POLICY" in
  always|missing|never) ;;
  *) echo "LISA_PULL_POLICY must be always, missing, or never." >&2; exit 1 ;;
esac
export LISA_EFFECTIVE_PULL_POLICY="$PULL_POLICY"

# shellcheck disable=SC1091
. "$EDGE_REPO/scripts/lib/compose.sh"
# shellcheck disable=SC1091
. "$EDGE_REPO/scripts/lib/images.sh"
lisa_build_compose_files "$EDGE_REPO"
lisa_validate_selected_images
echo "[LISA] Selected container images:"
lisa_print_selected_images
FILES=("${LISA_COMPOSE_FILES[@]}")
UP_ARGS=(-d --remove-orphans)

if [ "$PULL_POLICY" = "always" ]; then
  echo "[LISA] Pulling selected service images..."
  docker compose --env-file .env "${FILES[@]}" pull
elif [ "$PULL_POLICY" = "never" ]; then
  UP_ARGS+=(--pull never)
fi

if lisa_has_service mqtt; then
  "$EDGE_REPO/scripts/prepare-mqtt.sh"
  docker compose --env-file .env "${FILES[@]}" up "${UP_ARGS[@]}" --force-recreate mosquitto
fi
docker compose --env-file .env "${FILES[@]}" up "${UP_ARGS[@]}"

if lisa_has_service otbr; then
  "$EDGE_REPO/scripts/otbr-init-or-restore.sh"
fi

"$EDGE_REPO/scripts/healthcheck.sh"
