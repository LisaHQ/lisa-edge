#!/usr/bin/env bash

configure_zigbee2mqtt() {
  echo
  echo "--- Zigbee2MQTT wizard ---"
  ask_value ZIGBEE_DONGLE "Zigbee coordinator device" "${ZIGBEE_DONGLE:-/dev/ttyACM0}"
  ask_value ZIGBEE2MQTT_BIND_ADDR "Zigbee2MQTT bind IP" "${ZIGBEE2MQTT_BIND_ADDR:-127.0.0.1}"
  ask_value ZIGBEE2MQTT_PORT "Zigbee2MQTT port" "${ZIGBEE2MQTT_PORT:-8080}"
  require_bind_address "ZIGBEE2MQTT_BIND_ADDR" "$ZIGBEE2MQTT_BIND_ADDR"
  require_port "ZIGBEE2MQTT_PORT" "$ZIGBEE2MQTT_PORT"
}
