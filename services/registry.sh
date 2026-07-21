#!/usr/bin/env bash

# Canonical catalog for deployable LISA Edge services. Keep selection keys
# stable because they are stored in .env and in backup archives.
# These globals look unused to IDE/shellcheck within this file, but every
# consumer (lib/compose.sh, services/list.sh, the provisioning wizard, tests)
# sources this file and reads them. Do not delete.
# shellcheck disable=SC2034
LISA_DEFAULT_SERVICES="mqtt uptime-kuma"
# shellcheck disable=SC2034
LISA_ALL_SERVICES="mqtt uptime-kuma ha matter otbr zigbee2mqtt node-red vpn-tailscale"

lisa_normalize_service_id() {
  case "$1" in
    tailscale) printf '%s\n' vpn-tailscale ;;
    home-assistant|homeassistant) printf '%s\n' ha ;;
    matter-server) printf '%s\n' matter ;;
    *) printf '%s\n' "$1" ;;
  esac
}

lisa_service_directory() {
  case "$1" in
    mqtt) printf '%s\n' mqtt ;;
    uptime-kuma) printf '%s\n' uptime-kuma ;;
    ha) printf '%s\n' home-assistant ;;
    matter) printf '%s\n' matter-server ;;
    otbr) printf '%s\n' otbr ;;
    zigbee2mqtt) printf '%s\n' zigbee2mqtt ;;
    node-red) printf '%s\n' node-red ;;
    vpn-tailscale) printf '%s\n' tailscale ;;
    *) return 1 ;;
  esac
}

lisa_service_name() {
  case "$1" in
    mqtt) printf '%s\n' 'MQTT (Mosquitto)' ;;
    uptime-kuma) printf '%s\n' 'Uptime Kuma' ;;
    ha) printf '%s\n' 'Home Assistant' ;;
    matter) printf '%s\n' 'Matter Server' ;;
    otbr) printf '%s\n' 'OpenThread Border Router' ;;
    zigbee2mqtt) printf '%s\n' 'Zigbee2MQTT' ;;
    node-red) printf '%s\n' 'Node-RED' ;;
    vpn-tailscale) printf '%s\n' 'Tailscale VPN' ;;
    *) return 1 ;;
  esac
}

lisa_service_description() {
  case "$1" in
    mqtt) printf '%s\n' 'Local event and messaging backbone' ;;
    uptime-kuma) printf '%s\n' 'Lightweight service monitoring' ;;
    ha) printf '%s\n' 'Optional compact-host home automation controller' ;;
    matter) printf '%s\n' 'Optional local Matter controller server' ;;
    otbr) printf '%s\n' 'Thread border router for Matter-over-Thread' ;;
    zigbee2mqtt) printf '%s\n' 'Optional Zigbee-to-MQTT bridge' ;;
    node-red) printf '%s\n' 'Optional compact-host automation flows' ;;
    vpn-tailscale) printf '%s\n' 'Private remote administration' ;;
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
    ha) printf '%s\n' configure_ha ;;
    matter) printf '%s\n' configure_matter ;;
    otbr) printf '%s\n' configure_otbr ;;
    zigbee2mqtt) printf '%s\n' configure_zigbee2mqtt ;;
    node-red) printf '%s\n' configure_node_red ;;
    vpn-tailscale) printf '%s\n' configure_vpn_tailscale ;;
    *) return 1 ;;
  esac
}

lisa_service_image_variable() {
  case "$1" in
    mqtt) printf '%s\n' MQTT_IMAGE ;;
    uptime-kuma) printf '%s\n' UPTIME_KUMA_IMAGE ;;
    ha) printf '%s\n' HOME_ASSISTANT_IMAGE ;;
    matter) printf '%s\n' MATTER_SERVER_IMAGE ;;
    otbr) printf '%s\n' OTBR_IMAGE ;;
    zigbee2mqtt) printf '%s\n' ZIGBEE2MQTT_IMAGE ;;
    node-red) printf '%s\n' NODE_RED_IMAGE ;;
    vpn-tailscale) printf '%s\n' TAILSCALE_IMAGE ;;
    *) return 1 ;;
  esac
}

lisa_service_is_default() {
  case " $LISA_DEFAULT_SERVICES " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}
