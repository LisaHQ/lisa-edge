#!/usr/bin/env bash

lisa_image_ref_for_service() {
  case "$1" in
    mqtt) printf '%s\n' "${MQTT_IMAGE:-}" ;;
    uptime-kuma) printf '%s\n' "${UPTIME_KUMA_IMAGE:-}" ;;
    otbr) printf '%s\n' "${OTBR_IMAGE:-}" ;;
    vpn-tailscale) printf '%s\n' "${TAILSCALE_IMAGE:-}" ;;
    ha) printf '%s\n' "${HOME_ASSISTANT_IMAGE:-}" ;;
    zigbee2mqtt) printf '%s\n' "${ZIGBEE2MQTT_IMAGE:-}" ;;
    node-red) printf '%s\n' "${NODE_RED_IMAGE:-}" ;;
    *) return 1 ;;
  esac
}

lisa_is_pinned_image() {
  [[ "$1" =~ @sha256:[0-9a-fA-F]{64}$ ]]
}

lisa_print_selected_images() {
  local service image pin_status
  for service in $(lisa_selected_services); do
    image="$(lisa_image_ref_for_service "$service")"
    pin_status=floating
    lisa_is_pinned_image "$image" && pin_status=pinned
    printf '  %-15s %s [%s]\n' "$service" "$image" "$pin_status"
  done
}

lisa_validate_selected_images() {
  local require_pinned="${LISA_REQUIRE_PINNED_IMAGES:-0}"
  local service image

  case "$require_pinned" in
    0|1) ;;
    *) echo "LISA_REQUIRE_PINNED_IMAGES must be 0 or 1." >&2; return 1 ;;
  esac

  for service in $(lisa_selected_services); do
    image="$(lisa_image_ref_for_service "$service")"
    [ -n "$image" ] || {
      echo "Container image reference is empty for selected service: $service" >&2
      return 1
    }
    if [ "$require_pinned" = "1" ] && ! lisa_is_pinned_image "$image"; then
      echo "Selected service $service must use an immutable @sha256 digest: $image" >&2
      return 1
    fi
  done
}
