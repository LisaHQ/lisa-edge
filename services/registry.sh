#!/usr/bin/env bash

# Canonical catalog for deployable LISA Edge services. Keep selection keys
# stable because they are stored in .env and in backup archives.
LISA_DEFAULT_SERVICES="mqtt uptime-kuma"
LISA_ALL_SERVICES="mqtt uptime-kuma otbr vpn-tailscale ha zigbee2mqtt node-red"

lisa_normalize_service_id() {
  case "$1" in
    tailscale) printf '%s\n' vpn-tailscale ;;
    home-assistant|homeassistant) printf '%s\n' ha ;;
    *) printf '%s\n' "$1" ;;
  esac
}

lisa_service_directory() {
  case "$1" in
    mqtt) printf '%s\n' mqtt ;;
    uptime-kuma) printf '%s\n' uptime-kuma ;;
    otbr) printf '%s\n' otbr ;;
    vpn-tailscale) printf '%s\n' tailscale ;;
    ha) printf '%s\n' home-assistant ;;
    zigbee2mqtt) printf '%s\n' zigbee2mqtt ;;
    node-red) printf '%s\n' node-red ;;
    *) return 1 ;;
  esac
}

lisa_service_name() {
  case "$1" in
    mqtt) printf '%s\n' 'MQTT (Mosquitto)' ;;
    uptime-kuma) printf '%s\n' 'Uptime Kuma' ;;
    otbr) printf '%s\n' 'OpenThread Border Router' ;;
    vpn-tailscale) printf '%s\n' 'Tailscale VPN' ;;
    ha) printf '%s\n' 'Home Assistant' ;;
    zigbee2mqtt) printf '%s\n' 'Zigbee2MQTT' ;;
    node-red) printf '%s\n' 'Node-RED' ;;
    *) return 1 ;;
  esac
}

lisa_service_description() {
  case "$1" in
    mqtt) printf '%s\n' 'Local event and messaging backbone' ;;
    uptime-kuma) printf '%s\n' 'Lightweight service monitoring' ;;
    otbr) printf '%s\n' 'Thread border router for Matter-over-Thread' ;;
    vpn-tailscale) printf '%s\n' 'Private remote administration' ;;
    ha) printf '%s\n' 'Optional compact-host home automation controller' ;;
    zigbee2mqtt) printf '%s\n' 'Optional Zigbee-to-MQTT bridge' ;;
    node-red) printf '%s\n' 'Optional compact-host automation flows' ;;
    *) return 1 ;;
  esac
}

lisa_service_dependencies() {
  case "$1" in
    zigbee2mqtt) printf '%s\n' mqtt ;;
    *) printf '\n' ;;
  esac
}

lisa_service_configure_function() {
  case "$1" in
    mqtt) printf '%s\n' configure_mqtt ;;
    uptime-kuma) printf '%s\n' configure_uptime_kuma ;;
    otbr) printf '%s\n' configure_otbr ;;
    vpn-tailscale) printf '%s\n' configure_vpn_tailscale ;;
    ha) printf '%s\n' configure_ha ;;
    zigbee2mqtt) printf '%s\n' configure_zigbee2mqtt ;;
    node-red) printf '%s\n' configure_node_red ;;
    *) return 1 ;;
  esac
}

lisa_service_image_variable() {
  case "$1" in
    mqtt) printf '%s\n' MQTT_IMAGE ;;
    uptime-kuma) printf '%s\n' UPTIME_KUMA_IMAGE ;;
    otbr) printf '%s\n' OTBR_IMAGE ;;
    vpn-tailscale) printf '%s\n' TAILSCALE_IMAGE ;;
    ha) printf '%s\n' HOME_ASSISTANT_IMAGE ;;
    zigbee2mqtt) printf '%s\n' ZIGBEE2MQTT_IMAGE ;;
    node-red) printf '%s\n' NODE_RED_IMAGE ;;
    *) return 1 ;;
  esac
}

lisa_service_is_default() {
  case " $LISA_DEFAULT_SERVICES " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}
