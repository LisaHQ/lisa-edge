#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ -f "$EDGE_REPO/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$EDGE_REPO/.env"
  set +a
fi

DATA_ROOT="${DATA_ROOT:-/srv/lisa-edge}"
MQTT_USERNAME="${MQTT_USERNAME:-lisa}"
MQTT_PASSWORD="${MQTT_PASSWORD:-}"
MQTT_IMAGE="${MQTT_IMAGE:-eclipse-mosquitto:2}"
MOSQUITTO_CONFIG_DIR="$DATA_ROOT/docker/volumes/mosquitto/config"
MOSQUITTO_CONFIG="$MOSQUITTO_CONFIG_DIR/mosquitto.conf"
MOSQUITTO_PASSWORDS="$MOSQUITTO_CONFIG_DIR/passwords"

# shellcheck disable=SC1091
. "$EDGE_REPO/lib/paths.sh"
lisa_validate_persistent_path DATA_ROOT "$DATA_ROOT"

if [ -z "$MQTT_PASSWORD" ] || [ "$MQTT_PASSWORD" = "change-this-password" ] || [ "$MQTT_PASSWORD" = "changeme" ]; then
  echo "MQTT_PASSWORD must be changed from the template value before deployment." >&2
  exit 1
fi

mkdir -p "$MOSQUITTO_CONFIG_DIR"

if [ ! -f "$EDGE_REPO/services/mqtt/config/mosquitto.conf" ]; then
  echo "Missing source config: $EDGE_REPO/services/mqtt/config/mosquitto.conf" >&2
  exit 1
fi

cp "$EDGE_REPO/services/mqtt/config/mosquitto.conf" "$MOSQUITTO_CONFIG"

rm -f "$MOSQUITTO_PASSWORDS.new"
if [ "${LISA_EFFECTIVE_PULL_POLICY:-missing}" = "never" ] && ! docker image inspect "$MQTT_IMAGE" >/dev/null 2>&1; then
  echo "MQTT image is not available locally in offline mode: $MQTT_IMAGE" >&2
  exit 1
fi
docker run --rm \
  -v "$MOSQUITTO_CONFIG_DIR:/mosquitto/config" \
  "$MQTT_IMAGE" \
  mosquitto_passwd -b -c /mosquitto/config/passwords.new "$MQTT_USERNAME" "$MQTT_PASSWORD"

mv "$MOSQUITTO_PASSWORDS.new" "$MOSQUITTO_PASSWORDS"
chmod 0640 "$MOSQUITTO_CONFIG" "$MOSQUITTO_PASSWORDS"

echo "Mosquitto config and password file synchronized with .env."
