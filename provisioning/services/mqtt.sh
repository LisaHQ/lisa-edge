#!/usr/bin/env bash

configure_mqtt() {
  echo
  echo "--- MQTT wizard ---"
  ask_value MQTT_USERNAME "MQTT username" "${MQTT_USERNAME:-lisa}"
  ask_secret MQTT_PASSWORD "MQTT password" "${MQTT_PASSWORD:-}"
  if [ -z "$MQTT_PASSWORD" ] || [ "$MQTT_PASSWORD" = "change-this-password" ]; then
    MQTT_PASSWORD="$(generate_hex_secret)"
    info "Generated a random MQTT password."
  fi
  ask_value MQTT_BIND_ADDR "MQTT bind IP" "${MQTT_BIND_ADDR:-127.0.0.1}"
  ask_value MQTT_PORT "MQTT TCP port" "${MQTT_PORT:-1883}"
  ask_value MQTT_WS_PORT "MQTT WebSocket port" "${MQTT_WS_PORT:-9001}"
  require_port "MQTT_PORT" "$MQTT_PORT"
  require_port "MQTT_WS_PORT" "$MQTT_WS_PORT"
}
