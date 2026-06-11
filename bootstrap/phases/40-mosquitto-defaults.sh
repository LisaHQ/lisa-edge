#!/usr/bin/env bash
set -euo pipefail
DATA_ROOT="${DATA_ROOT:-/srv/lisa-edge}"
CONF="$DATA_ROOT/docker/volumes/mosquitto/config/mosquitto.conf"
if [ ! -f "$CONF" ]; then
cat >"$CONF" <<'EOC'
persistence true
persistence_location /mosquitto/data/
log_dest stdout
listener 1883
allow_anonymous true
listener 9001
protocol websockets
allow_anonymous true
EOC
fi
