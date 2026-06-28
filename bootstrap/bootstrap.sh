#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

log() { echo "[lisa-edge bootstrap] $*"; }

log "Ensure script permissions..."

chmod +x "$REPO_ROOT"/bootstrap/*.sh
chmod +x "$REPO_ROOT"/bootstrap/phases/*.sh
chmod +x "$REPO_ROOT"/scripts/*.sh

log "Starting bootstrap..."

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

cd "$REPO_DIR"

log "Loading environment"
if [ ! -f ".env" ]; then
  cp "$REPO_DIR/.env.example" ".env"
fi
if [ -f ".env" ]; then
  set -a
  source ".env"
  set +a
fi

log "Running bootstrap modules"
for script in "$REPO_DIR"/bootstrap/phases/*.sh
do
  [ -f "$script" ] || continue
  log "================================="
  log "Executing $(basename "$script")"
  log "================================="
  bash "$script"
done

log "Deploying services"
"$REPO_DIR/scripts/deploy.sh"
"$REPO_DIR/scripts/install-systemd.sh"

log "Bootstrap completed successfully"