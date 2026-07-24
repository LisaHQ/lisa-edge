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

# Print every vYYYY.MM.N release tag found in Docker Hub tag-list JSON on
# stdin, one per line. Prints nothing when no release tag is present.
otbr_release_tags_from_page() {
  grep -oE '"name"[[:space:]]*:[[:space:]]*"v[0-9]{4}\.[0-9]{2}\.[0-9]+"' |
    grep -oE 'v[0-9]{4}\.[0-9]{2}\.[0-9]+' || true
}

# Read Docker Hub tag-list JSON on stdin and print the newest vYYYY.MM.N
# release tag. Prints nothing when no release tag is present.
otbr_latest_release_tag() {
  otbr_release_tags_from_page | sort -uV | tail -n 1
}

# Print the "next" page URL from Docker Hub tag-list JSON on stdin, or
# nothing at the last page. Only hub.docker.com URLs are followed, so a
# hostile response cannot redirect the query elsewhere.
otbr_tags_next_url() {
  local url
  url="$(grep -oE '"next"[[:space:]]*:[[:space:]]*"[^"]+"' |
    head -n 1 | sed -E 's/.*"next"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  case "$url" in
    https://hub.docker.com/*) printf '%s\n' "$url" ;;
    *) : ;;
  esac
}

# Fetch one URL with a bounded timeout. Overridable in tests.
otbr_fetch_url() {
  curl -fsS --max-time "${OTBR_IMAGE_QUERY_TIMEOUT:-8}" "$1" 2>/dev/null
}

# Print the OTBR release tags found on Docker Hub, newest first and unique,
# following tag-list pagination with a bounded page count (release tags are
# not guaranteed to appear on the first page between releases). Fails
# (non-zero) when offline, curl is missing, or no release tag exists on any
# fetched page.
otbr_query_release_tags() {
  local url="https://hub.docker.com/v2/repositories/$OTBR_IMAGE_REPOSITORY/tags?page_size=100"
  local max_pages="${OTBR_IMAGE_QUERY_MAX_PAGES:-5}"
  local pages=0 response all_tags="" tags
  command -v curl >/dev/null 2>&1 || return 1
  while [ -n "$url" ] && [ "$pages" -lt "$max_pages" ]; do
    response="$(otbr_fetch_url "$url")" || return 1
    all_tags+="$(printf '%s' "$response" | otbr_release_tags_from_page)"$'\n'
    url="$(printf '%s' "$response" | otbr_tags_next_url)"
    pages=$((pages + 1))
  done
  tags="$(printf '%s' "$all_tags" | grep -E '^v' | sort -urV || true)"
  [ -n "$tags" ] || return 1
  printf '%s\n' "$tags"
}

# Resolve the newest OTBR release image reference from Docker Hub.
otbr_query_latest_image() {
  local tags
  tags="$(otbr_query_release_tags)" || return 1
  printf '%s:%s\n' "$OTBR_IMAGE_REPOSITORY" "$(head -n 1 <<<"$tags")"
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
  local default_image="$current_image" release_tags="" options=() tag count=0
  if otbr_image_is_floating "$current_image"; then
    info "Resolving recent OTBR release tags from Docker Hub..."
    if release_tags="$(otbr_query_release_tags)"; then
      # Offer the newest releases as a numbered menu; the newest one stays
      # the default (a custom reference can still be typed in).
      while IFS= read -r tag; do
        [ "$count" -lt "${OTBR_IMAGE_CHOICE_COUNT:-5}" ] || break
        options+=("$OTBR_IMAGE_REPOSITORY:$tag")
        count=$((count + 1))
      done <<<"$release_tags"
      default_image="${options[0]}"
      ask_choice OTBR_IMAGE "Recent OTBR release images (newest first)" \
        "$default_image" "${options[@]}"
      return 0
    fi
    warn "Could not resolve OTBR release tags (offline or Docker Hub unreachable); keeping $current_image."
  fi
  ask_value OTBR_IMAGE "OTBR container image" "$default_image"
}

# True when the lisa-otbr container is currently running on this host.
otbr_container_running() {
  command -v docker >/dev/null 2>&1 || return 1
  grep -qx lisa-otbr <<<"$(docker ps --format '{{.Names}}' 2>/dev/null || true)"
}

# Detect existing Thread dataset backups and stage the operator's choice as a
# one-shot pending marker consumed by dataset/init-or-restore.sh on deploy.
configure_otbr_dataset_source() {
  local search_root="" selection="" description="" answer choice item index
  local backups=() default_choice otbr_running=0
  local pending_dataset pending_new_network

  # shellcheck disable=SC1091
  . "$EDGE_REPO/services/otbr/dataset/lib.sh"
  pending_dataset="$OTBR_DATASET_BACKUP_DIR/$OTBR_PENDING_DATASET_FILE_NAME"
  pending_new_network="$OTBR_DATASET_BACKUP_DIR/$OTBR_PENDING_NEW_NETWORK_FILE_NAME"
  otbr_container_running && otbr_running=1

  echo
  echo "--- Thread dataset detection ---"
  if [ -d "$OTBR_DATASET_BACKUP_DIR" ]; then
    ask_choice search_root "Path to scan for Thread dataset backups" \
      "$OTBR_DATASET_BACKUP_DIR" "$OTBR_DATASET_BACKUP_DIR"
  else
    info "Default dataset backup directory does not exist yet: $OTBR_DATASET_BACKUP_DIR"
    ask_value search_root "Custom path to scan for dataset backups (directory or .hex file, Enter to skip)" ""
  fi

  if [ -z "$search_root" ]; then
    info "Skipping Thread dataset detection."
  elif [ -f "$search_root" ]; then
    selection="$search_root"
  elif [ -d "$search_root" ]; then
    mapfile -t backups < <(otbr_list_dataset_backup_files "$search_root")
    if [ "${#backups[@]}" -gt 0 ]; then
      echo "Detected Thread dataset backups (newest first):"
      index=1
      for item in "${backups[@]}"; do
        printf '  %d) %s\n' "$index" "$item"
        index=$((index + 1))
      done
      echo "  n) Create a new Thread network instead"
      echo "  s) Skip (keep the current dataset behavior)"
      # Default to the safe choice when a border router is already running.
      default_choice=1
      [ "$otbr_running" -eq 1 ] && default_choice=s
      while :; do
        read -r -p "Select a backup to restore, n, or s [$default_choice]: " choice
        choice="${choice:-$default_choice}"
        case "$choice" in
          n|N) selection="new"; break ;;
          s|S) selection=""; break ;;
          *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#backups[@]}" ]; then
              selection="${backups[$((choice - 1))]}"
              break
            fi
            echo "Invalid selection. Try again." >&2
            ;;
        esac
      done
    else
      warn "No Thread dataset backup (*.hex) was found under $search_root."
      ask_yes_no answer "Create a new Thread network on the next deployment" "no"
      [ "$answer" = "yes" ] && selection="new"
    fi
  else
    warn "Dataset backup path does not exist: $search_root. Skipping detection."
  fi

  if [ -z "$selection" ]; then
    if [ "${DRY_RUN:-0}" -eq 0 ] &&
      { [ -e "$pending_dataset" ] || [ -e "$pending_new_network" ]; }; then
      rm -f -- "$pending_dataset" "$pending_new_network"
      info "Cleared a previously staged dataset selection."
    fi
    return 0
  fi

  if [ "$selection" != "new" ] && ! otbr_dataset_file_is_valid_hex "$selection"; then
    die "Selected dataset file is not a valid hex dataset: $selection"
  fi

  if [ "$otbr_running" -eq 1 ]; then
    info "OTBR is currently running. Its active dataset will be backed up before the selected change is applied."
    ask_yes_no answer "Add a description to that backup's filename" "no"
    if [ "$answer" = "yes" ]; then
      ask_value description "Backup description (sanitized for the filename)" ""
    fi
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
      info "Dry run: backup of the running dataset skipped."
    elif "$EDGE_REPO/services/otbr/dataset/backup.sh" ${description:+--label "$description"}; then
      :
    else
      warn "Could not back up the running dataset now; deploy backs it up again before applying the change."
    fi
  fi

  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    info "Dry run: dataset selection is not staged."
    return 0
  fi

  mkdir -p "$OTBR_DATASET_BACKUP_DIR"
  chmod 0700 "$OTBR_DATASET_BACKUP_DIR"
  if [ "$selection" = "new" ]; then
    rm -f -- "$pending_dataset"
    : > "$pending_new_network"
    chmod 0600 "$pending_new_network"
    info "Staged: a NEW Thread network will be created on the next deploy."
    warn "Creating a new network disconnects devices paired to a previous Thread network."
  else
    rm -f -- "$pending_new_network"
    if [ ! "$selection" -ef "$pending_dataset" ]; then
      install -m 0600 -- "$selection" "$pending_dataset"
    fi
    info "Staged dataset for restore on the next deploy: $selection"
  fi
  info "To cancel before deploying, delete $pending_dataset and $pending_new_network."
}

# Ask for the Thread network name (used when a NEW network is created; an
# established network is never renamed). The name identifies the logical
# site mesh, not the host, the border router, or the radio: it must survive
# hardware replacement.
configure_otbr_network_name() {
  # shellcheck disable=SC1091
  . "$EDGE_REPO/lib/service-config.sh"
  while :; do
    ask_value THREAD_NETWORK_NAME \
      "Thread network name (max 16 bytes, used when creating a NEW network)" \
      "${THREAD_NETWORK_NAME:-LISA-HOME-01}"
    if lisa_validate_thread_network_name "$THREAD_NETWORK_NAME"; then
      break
    fi
    echo "Try again." >&2
  done
}

configure_otbr() {
  local answer
  echo
  echo "--- OpenThread Border Router wizard ---"
  configure_otbr_radio
  configure_otbr_backbone
  configure_otbr_image
  configure_otbr_network_name
  ask_value OTBR_THREAD_IF "Thread interface name (custom allowed, max 15 chars; default recommended)" "${OTBR_THREAD_IF:-wpan0}"
  ask_value OTBR_LOG_LEVEL "OTBR log level" "${OTBR_LOG_LEVEL:-5}"
  ask_value OTBR_DATASET_BACKUP_DIR "Thread dataset backup directory" "${OTBR_DATASET_BACKUP_DIR:-$DATA_ROOT/backups/otbr}"
  require_persistent_data_path "OTBR_DATASET_BACKUP_DIR" "$OTBR_DATASET_BACKUP_DIR"
  # Looks unused here, but lisa-first-boot.sh writes it into .env via env_line().
  # shellcheck disable=SC2034
  OTBR_DATASET_LATEST="$OTBR_DATASET_BACKUP_DIR/latest.dataset.hex"
  configure_otbr_dataset_source
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
