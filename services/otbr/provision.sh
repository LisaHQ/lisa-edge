#!/usr/bin/env bash

OTBR_IMAGE_REPOSITORY="openthread/border-router"

# Print one /dev/serial/by-id/ device path per line. Empty output when no
# serial radio is attached.
otbr_detect_serial_devices() {
  local device
  for device in /dev/serial/by-id/*; do
    [ -e "$device" ] || continue
    printf '%s\n' "$device"
  done
}

# Print administratively-up host interfaces that can plausibly carry the OTBR
# backbone, excluding loopback and container/VPN/Thread virtual interfaces.
otbr_detect_active_interfaces() {
  command -v ip >/dev/null 2>&1 || return 0
  ip -o link show up 2>/dev/null | awk -F': ' '{print $2}' | cut -d@ -f1 |
    grep -Ev '^(lo|docker.*|br-.*|veth.*|wpan.*|tailscale.*|tun.*|tap.*|virbr.*)$' || true
}

# Print the interface carrying the IPv4 default route, if any.
otbr_default_route_interface() {
  command -v ip >/dev/null 2>&1 || return 0
  ip -4 route show default 2>/dev/null |
    awk '{for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit }}'
}

# Read Docker Hub tag-list JSON on stdin and print the newest vYYYY.MM.N
# release tag. Prints nothing when no release tag is present.
otbr_latest_release_tag() {
  grep -oE '"name"[[:space:]]*:[[:space:]]*"v[0-9]{4}\.[0-9]{2}\.[0-9]+"' |
    grep -oE 'v[0-9]{4}\.[0-9]{2}\.[0-9]+' | sort -uV | tail -n 1
}

# Resolve the newest OTBR release image reference from Docker Hub.
# Fails (non-zero) when offline, curl is missing, or no release tag exists.
otbr_query_latest_image() {
  local url="https://hub.docker.com/v2/repositories/$OTBR_IMAGE_REPOSITORY/tags?page_size=100"
  local response tag
  command -v curl >/dev/null 2>&1 || return 1
  response="$(curl -fsS --max-time "${OTBR_IMAGE_QUERY_TIMEOUT:-8}" "$url" 2>/dev/null)" || return 1
  tag="$(printf '%s' "$response" | otbr_latest_release_tag)"
  [ -n "$tag" ] || return 1
  printf '%s:%s\n' "$OTBR_IMAGE_REPOSITORY" "$tag"
}

# True when the image reference is the default repository on a floating tag.
# Pinned digests, release tags, and custom registries are left untouched.
otbr_image_is_floating() {
  local image="$1"
  if lisa_is_pinned_image "$image"; then
    return 1
  fi
  case "$image" in
    "$OTBR_IMAGE_REPOSITORY" | "$OTBR_IMAGE_REPOSITORY:latest" | "$OTBR_IMAGE_REPOSITORY:main") return 0 ;;
    *) return 1 ;;
  esac
}

configure_otbr_radio() {
  local devices=() default_device device
  mapfile -t devices < <(otbr_detect_serial_devices)
  if [ "${#devices[@]}" -gt 0 ]; then
    default_device="${devices[0]}"
    for device in "${devices[@]}"; do
      if [ "$device" = "${THREAD_RADIO_DEVICE:-}" ]; then
        default_device="$device"
      fi
    done
    ask_choice THREAD_RADIO_DEVICE "Detected serial devices (Thread RCP radio)" \
      "$default_device" "${devices[@]}"
  else
    warn "No serial device was found under /dev/serial/by-id/."
    echo "  Connect the Thread RCP dongle, then verify it appears with:"
    echo "    ls -l /dev/serial/by-id/"
    echo "    dmesg | tail -n 20"
    echo "  VM deployments must pass the USB radio through to this guest."
    ask_value THREAD_RADIO_DEVICE "Thread RCP device (/dev/serial/by-id/...)" \
      "${THREAD_RADIO_DEVICE:-/dev/serial/by-id/YOUR_THREAD_RCP_RADIO}"
  fi
  case "$THREAD_RADIO_DEVICE" in
    *YOUR_THREAD_RCP_RADIO*)
      warn "THREAD_RADIO_DEVICE still uses the placeholder; OTBR cannot deploy until it points at a real radio."
      ;;
    *)
      if [ ! -e "$THREAD_RADIO_DEVICE" ]; then
        warn "THREAD_RADIO_DEVICE does not exist yet: $THREAD_RADIO_DEVICE (OTBR will fail to start until it is present)."
      fi
      ;;
  esac
}

configure_otbr_backbone() {
  local interfaces=() default_interface route_interface interface
  mapfile -t interfaces < <(otbr_detect_active_interfaces)
  if [ "${#interfaces[@]}" -gt 0 ]; then
    default_interface="${interfaces[0]}"
    route_interface="$(otbr_default_route_interface)"
    for interface in "${interfaces[@]}"; do
      if [ "$interface" = "$route_interface" ]; then
        default_interface="$interface"
      fi
    done
    for interface in "${interfaces[@]}"; do
      if [ "$interface" = "${OTBR_BACKBONE_IF:-}" ]; then
        default_interface="$interface"
      fi
    done
    ask_choice OTBR_BACKBONE_IF "Active network interfaces (OTBR backbone)" \
      "$default_interface" "${interfaces[@]}"
  else
    ask_value OTBR_BACKBONE_IF "OTBR backbone network interface" "${OTBR_BACKBONE_IF:-enp1s0}"
  fi
}

configure_otbr_image() {
  local current_image="${OTBR_IMAGE:-$OTBR_IMAGE_REPOSITORY:latest}"
  local default_image="$current_image" detected_image
  if otbr_image_is_floating "$current_image"; then
    info "Resolving the latest OTBR release tag from Docker Hub..."
    if detected_image="$(otbr_query_latest_image)"; then
      default_image="$detected_image"
    else
      warn "Could not resolve an OTBR release tag (offline or Docker Hub unreachable); keeping $current_image."
    fi
  fi
  ask_value OTBR_IMAGE "OTBR container image" "$default_image"
}

configure_otbr() {
  local answer
  echo
  echo "--- OpenThread Border Router wizard ---"
  configure_otbr_radio
  configure_otbr_backbone
  configure_otbr_image
  ask_value OTBR_THREAD_IF "Thread interface name" "${OTBR_THREAD_IF:-wpan0}"
  ask_value OTBR_LOG_LEVEL "OTBR log level" "${OTBR_LOG_LEVEL:-5}"
  ask_value OTBR_DATASET_BACKUP_DIR "Thread dataset backup directory" "${OTBR_DATASET_BACKUP_DIR:-$DATA_ROOT/backups/otbr}"
  require_persistent_data_path "OTBR_DATASET_BACKUP_DIR" "$OTBR_DATASET_BACKUP_DIR"
  # Looks unused here, but lisa-first-boot.sh writes it into .env via env_line().
  # shellcheck disable=SC2034
  OTBR_DATASET_LATEST="$OTBR_DATASET_BACKUP_DIR/latest.dataset.hex"
  ask_yes_no answer "Automatically restore the latest Thread dataset" "yes"
  # OTBR_AUTO_RESTORE_DATASET looks unused here, but lisa-first-boot.sh writes it into .env via env_line().
  # shellcheck disable=SC2034
  [ "$answer" = "yes" ] && OTBR_AUTO_RESTORE_DATASET=1 || OTBR_AUTO_RESTORE_DATASET=0
  ask_yes_no answer "Allow creating a new Thread network when no backup exists" "no"
  # OTBR_AUTO_CREATE_NETWORK looks unused here, but lisa-first-boot.sh writes it into .env via env_line().
  # shellcheck disable=SC2034
  [ "$answer" = "yes" ] && OTBR_AUTO_CREATE_NETWORK=1 || OTBR_AUTO_CREATE_NETWORK=0
  # Consumed by install/bootstrap/phases/40-core-service-prep.sh and written to .env.
  # shellcheck disable=SC2034
  LISA_ENABLE_THREAD_HOST_PREP=1
}
