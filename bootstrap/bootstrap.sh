#!/usr/bin/env bash
set -euo pipefail

EDGE_DIR="${EDGE_DIR:-/opt/lisa-edge}"
ENV_FILE="$EDGE_DIR/.env"

log() { echo "[lisa-edge bootstrap] $*"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

cd "$EDGE_DIR"

log "Loading environment"
if [ ! -f "$ENV_FILE" ]; then
  cp "$EDGE_DIR/.env.example" "$ENV_FILE"
fi
set -a
. "$ENV_FILE"
set +a

log "Running bootstrap modules"
for script in "$EDGE_DIR"/bootstrap/scripts/*.sh; do
  log "Executing $(basename "$script")"
  bash "$script"
done

log "Deploying services"
"$EDGE_DIR/scripts/deploy.sh"

log "Bootstrap completed"
