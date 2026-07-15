#!/usr/bin/env bash

configure_uptime_kuma() {
  echo
  echo "--- Uptime Kuma wizard ---"
  ask_value UPTIME_KUMA_BIND_ADDR "Uptime Kuma bind IP" "${UPTIME_KUMA_BIND_ADDR:-127.0.0.1}"
  ask_value UPTIME_KUMA_PORT "Uptime Kuma port" "${UPTIME_KUMA_PORT:-3001}"
  require_bind_address "UPTIME_KUMA_BIND_ADDR" "$UPTIME_KUMA_BIND_ADDR"
  require_port "UPTIME_KUMA_PORT" "$UPTIME_KUMA_PORT"
}
