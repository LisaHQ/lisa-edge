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

wait_for_tcp() {
  local label="$1"
  local host="$2"
  local port="$3"

  for _ in $(seq 1 30); do
    if check_tcp "$host" "$port"; then
      echo "[LISA] $label is accepting connections on $host:$port."
      return 0
    fi
    sleep 2
  done

  echo "[LISA] $label did not become ready on $host:$port." >&2
  return 1
}

check_container() {
  local name="$1"
  local running
  running="$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || true)"
  if [ "$running" != "true" ]; then
    echo "[LISA] Container is not running: $name" >&2
    return 1
  fi
}

echo "[LISA] Checking containers..."
docker compose --env-file .env "${FILES[@]}" ps

check_container lisa-mqtt
check_container lisa-uptime

for service in ${LISA_COMPOSE_SERVICES:-}; do
  case "$service" in
    otbr) check_container lisa-otbr ;;
    ha) check_container lisa-ha ;;
    zigbee2mqtt) check_container lisa-zigbee2mqtt ;;
    node-red) check_container lisa-node-red ;;
    vpn-tailscale) check_container lisa-tailscale ;;
  esac
done

echo "[LISA] Checking MQTT port..."
wait_for_tcp "MQTT" "${HEALTHCHECK_BIND_ADDR:-127.0.0.1}" "${MQTT_PORT:-1883}"

echo "[LISA] Checking Uptime Kuma port..."
wait_for_tcp "Uptime Kuma" "${HEALTHCHECK_BIND_ADDR:-127.0.0.1}" "${UPTIME_KUMA_PORT:-3001}"

if echo "${LISA_COMPOSE_SERVICES:-}" | grep -qw zigbee2mqtt; then
  wait_for_tcp "Zigbee2MQTT" "${HEALTHCHECK_BIND_ADDR:-127.0.0.1}" "${ZIGBEE2MQTT_PORT:-8080}"
fi

if echo "${LISA_COMPOSE_SERVICES:-}" | grep -qw node-red; then
  wait_for_tcp "Node-RED" "${HEALTHCHECK_BIND_ADDR:-127.0.0.1}" "${NODE_RED_PORT:-1880}"
fi

echo "[LISA] Edge core stack healthy."
