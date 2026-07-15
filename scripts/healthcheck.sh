#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

set -a
# shellcheck disable=SC1091
. ./.env
set +a

# shellcheck disable=SC1091
. "$EDGE_REPO/scripts/lib/compose.sh"
lisa_build_compose_files "$EDGE_REPO"
FILES=("${LISA_COMPOSE_FILES[@]}")

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

healthcheck_host() {
  local bind_address="$1"
  if [ "${HEALTHCHECK_BIND_ADDR:-auto}" != "auto" ]; then
    printf '%s\n' "$HEALTHCHECK_BIND_ADDR"
  elif [ "$bind_address" = "0.0.0.0" ]; then
    printf '127.0.0.1\n'
  else
    printf '%s\n' "$bind_address"
  fi
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

if lisa_has_service mqtt; then
  check_container lisa-mqtt
fi

if lisa_has_service uptime-kuma; then
  check_container lisa-uptime
fi

for service in $(lisa_selected_services); do
  case "$service" in
    otbr) check_container lisa-otbr ;;
    ha) check_container lisa-ha ;;
    zigbee2mqtt) check_container lisa-zigbee2mqtt ;;
    node-red) check_container lisa-node-red ;;
    vpn-tailscale) check_container lisa-tailscale ;;
  esac
done

if lisa_has_service mqtt; then
  echo "[LISA] Checking MQTT port..."
  wait_for_tcp "MQTT" "$(healthcheck_host "${MQTT_BIND_ADDR:-127.0.0.1}")" "${MQTT_PORT:-1883}"
fi

if lisa_has_service uptime-kuma; then
  echo "[LISA] Checking Uptime Kuma port..."
  wait_for_tcp "Uptime Kuma" "$(healthcheck_host "${UPTIME_KUMA_BIND_ADDR:-127.0.0.1}")" "${UPTIME_KUMA_PORT:-3001}"
fi

if lisa_has_service zigbee2mqtt; then
  wait_for_tcp "Zigbee2MQTT" "$(healthcheck_host "${ZIGBEE2MQTT_BIND_ADDR:-127.0.0.1}")" "${ZIGBEE2MQTT_PORT:-8080}"
fi

if lisa_has_service node-red; then
  wait_for_tcp "Node-RED" "$(healthcheck_host "${NODE_RED_BIND_ADDR:-127.0.0.1}")" "${NODE_RED_PORT:-1880}"
fi

echo "[LISA] Selected LISA Edge services are healthy."
