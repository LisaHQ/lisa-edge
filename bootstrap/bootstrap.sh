#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

log() { echo "[lisa-edge bootstrap] $*"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

log "Starting bootstrap..."
log "Ensuring script permissions..."

chmod +x "$REPO_DIR"/bootstrap/*.sh
chmod +x "$REPO_DIR"/bootstrap/phases/*.sh
chmod +x "$REPO_DIR"/scripts/*.sh
chmod +x "$REPO_DIR"/tools/*.sh
chmod +x "$REPO_DIR"/recovery/scripts/*.sh

cd "$REPO_DIR"

log "Loading environment"
if [ ! -f ".env" ]; then
  cp "$REPO_DIR/.env.template" ".env"

  MQTT_PASSWORD_GENERATED="$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')"
  if [ "${#MQTT_PASSWORD_GENERATED}" -ne 48 ]; then
    echo "Could not generate the initial MQTT password." >&2
    exit 1
  fi
  sed -i "s/^MQTT_PASSWORD=.*/MQTT_PASSWORD=$MQTT_PASSWORD_GENERATED/" ".env"
  unset MQTT_PASSWORD_GENERATED
fi
chmod 0600 ".env"
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
bash "$REPO_DIR/scripts/finalize-admin-access.sh"

log "Bootstrap completed successfully"
