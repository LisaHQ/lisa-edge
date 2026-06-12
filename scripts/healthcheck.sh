#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

set -a
# shellcheck disable=SC1091
. ./.env
set +a

FILES=(-f compose/docker-compose.yml)
for service in ${LISA_COMPOSE_SERVICES:-}; do
  [ -f "compose/services/$service.yml" ] && FILES+=(-f "compose/services/$service.yml")
done

check_tcp() {
  local host="$1"
  local port="$2"
  timeout 3 bash -c "</dev/tcp/${host}/${port}" >/dev/null 2>&1
}

echo "[LISA] Checking containers..."
docker compose --env-file .env "${FILES[@]}" ps

docker ps --format '{{.Names}}' | grep -q '^lisa-mqtt$'
docker ps --format '{{.Names}}' | grep -q '^lisa-uptime$'
docker ps --format '{{.Names}}' | grep -q '^lisa-backup-helper$'

echo "[LISA] Checking MQTT port..."
check_tcp 127.0.0.1 "${MQTT_PORT:-1883}"

echo "[LISA] Checking Uptime Kuma port..."
check_tcp 127.0.0.1 "${UPTIME_KUMA_PORT:-3001}"

echo "[LISA] Edge core stack healthy."
