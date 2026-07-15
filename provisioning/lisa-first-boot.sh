#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EDGE_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_OUTPUT="$EDGE_REPO/.env"
MODE=""
BACKUP_ARCHIVE=""
DRY_RUN=0

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/ui.sh"
for wizard in "$SCRIPT_DIR"/services/*.sh; do
  # shellcheck disable=SC1090
  . "$wizard"
done

SERVICE_IDS=(mqtt uptime-kuma otbr vpn-tailscale ha zigbee2mqtt node-red)
ALL_SERVICE_NAMES="${SERVICE_IDS[*]}"

usage() {
  cat <<'EOF'
Usage: sudo provisioning/lisa-first-boot.sh [options]

Options:
  --mode MODE       fresh, restore-usb, restore-path, or config-only
  --backup PATH     Backup archive or directory for restore-path
  --output PATH     Write environment file to PATH (default: repo .env)
  --dry-run         Run the wizard without writing or deploying
  -h, --help        Show this help
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --mode) MODE="${2:-}"; shift 2 ;;
      --backup) BACKUP_ARCHIVE="${2:-}"; shift 2 ;;
      --output) ENV_OUTPUT="${2:-}"; shift 2 ;;
      --dry-run) DRY_RUN=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
}

load_environment() {
  set -a
  # shellcheck disable=SC1091
  . "$EDGE_REPO/.env.template"
  if [ -f "$EDGE_REPO/.env" ]; then
    # shellcheck disable=SC1091
    . "$EDGE_REPO/.env"
  fi
  set +a
}

choose_mode() {
  local choice
  [ -n "$MODE" ] && return 0

  echo
  echo "Provisioning mode:"
  echo "  1) Fresh deployment"
  echo "  2) Restore from USB/local removable storage"
  echo "  3) Restore from a mounted NAS/local path"
  echo "  4) Configure .env only"
  read -r -p "Select mode [1]: " choice
  case "${choice:-1}" in
    1) MODE=fresh ;;
    2) MODE=restore-usb ;;
    3) MODE=restore-path ;;
    4) MODE=config-only ;;
    *) die "Invalid provisioning mode." ;;
  esac
}

service_description() {
  case "$1" in
    mqtt) echo "MQTT message broker" ;;
    uptime-kuma) echo "Uptime and endpoint monitoring" ;;
    otbr) echo "OpenThread Border Router" ;;
    vpn-tailscale) echo "Tailscale remote access" ;;
    ha) echo "Home Assistant" ;;
    zigbee2mqtt) echo "Zigbee coordinator bridge (requires MQTT)" ;;
    node-red) echo "Node-RED automation" ;;
  esac
}

contains_word() {
  local list="$1"
  local wanted="$2"
  case " $list " in *" $wanted "*) return 0 ;; *) return 1 ;; esac
}

select_services() {
  local current="${LISA_COMPOSE_SERVICES:-mqtt uptime-kuma}"
  local input token service selected=""
  local index=1

  [ "$current" = "all" ] && current="$ALL_SERVICE_NAMES"

  echo
  echo "Available services:"
  for service in "${SERVICE_IDS[@]}"; do
    printf '  %d) %-15s %s\n' "$index" "$service" "$(service_description "$service")"
    index=$((index + 1))
  done
  echo "  all) Install all services"
  echo
  echo "Current/default selection: $current"
  read -r -p "Select numbers or names separated by comma/space [keep current]: " input
  input="${input//,/ }"

  if [ -z "$input" ]; then
    selected="$current"
  elif [ "${input,,}" = "all" ]; then
    selected="$ALL_SERVICE_NAMES"
  else
    for token in $input; do
      case "$token" in
        1) service=mqtt ;;
        2) service=uptime-kuma ;;
        3) service=otbr ;;
        4) service=vpn-tailscale ;;
        5) service=ha ;;
        6) service=zigbee2mqtt ;;
        7) service=node-red ;;
        mqtt|uptime-kuma|otbr|vpn-tailscale|ha|zigbee2mqtt|node-red) service="$token" ;;
        *) die "Unknown service selection: $token" ;;
      esac
      contains_word "$selected" "$service" || selected="${selected:+$selected }$service"
    done
  fi

  [ -n "$selected" ] || die "Select at least one service."
  if contains_word "$selected" zigbee2mqtt && ! contains_word "$selected" mqtt; then
    selected="mqtt $selected"
    info "Added MQTT because Zigbee2MQTT depends on it."
  fi

  LISA_COMPOSE_SERVICES=""
  for service in "${SERVICE_IDS[@]}"; do
    if contains_word "$selected" "$service"; then
      LISA_COMPOSE_SERVICES="${LISA_COMPOSE_SERVICES:+$LISA_COMPOSE_SERVICES }$service"
    fi
  done
  info "Selected services: $LISA_COMPOSE_SERVICES"
}

configure_global() {
  echo
  echo "--- Host and storage wizard ---"
  ask_value LISA_EDGE_HOSTNAME "Hostname" "${LISA_EDGE_HOSTNAME:-lisa-edge-01}"
  [[ "$LISA_EDGE_HOSTNAME" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || die "Invalid hostname."
  ask_value TZ "Timezone" "${TZ:-America/Los_Angeles}"
  ask_value DATA_ROOT "Persistent data root" "${DATA_ROOT:-/srv/lisa-edge}"
  require_absolute_path "DATA_ROOT" "$DATA_ROOT"
  ask_value BACKUP_DEST "Backup destination (local path or mounted NAS path)" "${BACKUP_DEST:-$DATA_ROOT/backups}"
  require_absolute_path "BACKUP_DEST" "$BACKUP_DEST"
  ask_value BACKUP_RETENTION_DAYS "Backup retention in days" "${BACKUP_RETENTION_DAYS:-14}"
  [[ "$BACKUP_RETENTION_DAYS" =~ ^[0-9]+$ ]] || die "Retention must be numeric."
  ask_value HEALTHCHECK_BIND_ADDR "Healthcheck target IP" "${HEALTHCHECK_BIND_ADDR:-127.0.0.1}"
}

run_service_wizards() {
  local service
  for service in "${SERVICE_IDS[@]}"; do
    contains_word "$LISA_COMPOSE_SERVICES" "$service" || continue
    case "$service" in
      mqtt) configure_mqtt ;;
      uptime-kuma) configure_uptime_kuma ;;
      otbr) configure_otbr ;;
      vpn-tailscale) configure_vpn_tailscale ;;
      ha) configure_ha ;;
      zigbee2mqtt) configure_zigbee2mqtt ;;
      node-red) configure_node_red ;;
    esac
  done
}

choose_archive() {
  local search_root="$1"
  local archives=()
  local item choice index=1

  if [ -f "$search_root" ]; then
    BACKUP_ARCHIVE="$search_root"
    return 0
  fi
  [ -d "$search_root" ] || die "Backup path does not exist: $search_root"

  while IFS= read -r item; do archives+=("$item"); done < <(
    find "$search_root" -maxdepth 4 -type f -name 'lisa-edge-backup-*.tar.gz' | sort -r
  )
  [ "${#archives[@]}" -gt 0 ] || die "No LISA Edge backup archive found under $search_root"

  echo
  echo "Available backups:"
  for item in "${archives[@]}"; do
    printf '  %d) %s\n' "$index" "$item"
    index=$((index + 1))
  done
  read -r -p "Select backup [1]: " choice
  choice="${choice:-1}"
  [[ "$choice" =~ ^[0-9]+$ ]] || die "Invalid backup selection."
  [ "$choice" -ge 1 ] && [ "$choice" -le "${#archives[@]}" ] || die "Invalid backup selection."
  BACKUP_ARCHIVE="${archives[$((choice - 1))]}"
}

verify_backup_archive() {
  local checksum_file="$BACKUP_ARCHIVE.sha256"
  if [ -f "$checksum_file" ]; then
    info "Verifying backup checksum..."
    (cd "$(dirname "$BACKUP_ARCHIVE")" && sha256sum -c "$(basename "$checksum_file")")
  else
    warn "No checksum sidecar found for this backup."
  fi
}

discover_usb_backup() {
  local mount_dir="/mnt/lisa-backup"
  local root

  if [ -e /dev/disk/by-label/LISA_BACKUP ]; then
    mkdir -p "$mount_dir"
    if ! mountpoint -q "$mount_dir"; then
      mount -o ro /dev/disk/by-label/LISA_BACKUP "$mount_dir"
    fi
    choose_archive "$mount_dir"
    return 0
  fi

  for root in /media /run/media /mnt; do
    [ -d "$root" ] || continue
    if find "$root" -maxdepth 4 -type f -name 'lisa-edge-backup-*.tar.gz' -print -quit | grep -q .; then
      choose_archive "$root"
      return 0
    fi
  done
  die "No LISA_BACKUP volume or backup archive was found."
}

prepare_restore() {
  local path
  case "$MODE" in
    restore-usb)
      if [ -n "$BACKUP_ARCHIVE" ]; then choose_archive "$BACKUP_ARCHIVE"; else discover_usb_backup; fi
      ;;
    restore-path)
      if [ -z "$BACKUP_ARCHIVE" ]; then
        ask_value path "Mounted NAS directory or backup archive" ""
        BACKUP_ARCHIVE="$path"
      fi
      choose_archive "$BACKUP_ARCHIVE"
      ;;
    *) return 0 ;;
  esac

  info "Selected backup: $BACKUP_ARCHIVE"
  verify_backup_archive
  if [ "$DRY_RUN" -eq 1 ]; then
    info "Dry run: restore skipped."
  else
    "$EDGE_REPO/scripts/restore.sh" --no-deploy "$BACKUP_ARCHIVE"
    load_environment
  fi
}

env_line() {
  local key="$1"
  local value="${2:-}"
  case "$value" in
    *$'\n'*|*"'"*) die "$key contains an unsupported newline or single quote." ;;
  esac
  printf "%s='%s'\n" "$key" "$value"
}

write_environment() {
  local temp_file="$ENV_OUTPUT.tmp"
  local backup_file

  if [ "$DRY_RUN" -eq 1 ]; then
    echo
    info "Dry-run configuration summary:"
    echo "  mode: $MODE"
    echo "  hostname: $LISA_EDGE_HOSTNAME"
    echo "  data root: $DATA_ROOT"
    echo "  backup destination: $BACKUP_DEST"
    echo "  services: $LISA_COMPOSE_SERVICES"
    return 0
  fi

  mkdir -p "$(dirname "$ENV_OUTPUT")"
  if [ -f "$ENV_OUTPUT" ]; then
    backup_file="$ENV_OUTPUT.before-wizard-$(date +%Y%m%d-%H%M%S)"
    cp "$ENV_OUTPUT" "$backup_file"
    chmod 0600 "$backup_file"
  fi

  {
    env_line LISA_EDGE_HOSTNAME "$LISA_EDGE_HOSTNAME"
    env_line TZ "$TZ"
    env_line DATA_ROOT "$DATA_ROOT"
    env_line BACKUP_DEST "$BACKUP_DEST"
    env_line BACKUP_RETENTION_DAYS "$BACKUP_RETENTION_DAYS"
    env_line COMPOSE_PROJECT_NAME "${COMPOSE_PROJECT_NAME:-lisa-edge}"
    env_line LISA_COMPOSE_SERVICES "$LISA_COMPOSE_SERVICES"
    env_line HEALTHCHECK_BIND_ADDR "$HEALTHCHECK_BIND_ADDR"
    env_line MQTT_BIND_ADDR "${MQTT_BIND_ADDR:-127.0.0.1}"
    env_line MQTT_PORT "${MQTT_PORT:-1883}"
    env_line MQTT_WS_PORT "${MQTT_WS_PORT:-9001}"
    env_line MQTT_USERNAME "${MQTT_USERNAME:-lisa}"
    env_line MQTT_PASSWORD "${MQTT_PASSWORD:-}"
    env_line UPTIME_KUMA_BIND_ADDR "${UPTIME_KUMA_BIND_ADDR:-127.0.0.1}"
    env_line UPTIME_KUMA_PORT "${UPTIME_KUMA_PORT:-3001}"
    env_line LISA_ENABLE_THREAD_HOST_PREP "${LISA_ENABLE_THREAD_HOST_PREP:-0}"
    env_line THREAD_RADIO_DEVICE "${THREAD_RADIO_DEVICE:-/dev/serial/by-id/YOUR_THREAD_RCP_RADIO}"
    env_line THREAD_RADIO_URL "${THREAD_RADIO_URL:-spinel+hdlc+uart:///dev/ttyThreadRCP?uart-baudrate=460800}"
    env_line OTBR_BACKBONE_IF "${OTBR_BACKBONE_IF:-enp1s0}"
    env_line OTBR_THREAD_IF "${OTBR_THREAD_IF:-wpan0}"
    env_line OTBR_LOG_LEVEL "${OTBR_LOG_LEVEL:-5}"
    env_line OTBR_DATASET_BACKUP_DIR "${OTBR_DATASET_BACKUP_DIR:-$DATA_ROOT/backups/otbr}"
    env_line OTBR_DATASET_LATEST "${OTBR_DATASET_LATEST:-$DATA_ROOT/backups/otbr/latest.dataset.hex}"
    env_line OTBR_DATASET_RETENTION_DAYS "${OTBR_DATASET_RETENTION_DAYS:-30}"
    env_line OTBR_AUTO_RESTORE_DATASET "${OTBR_AUTO_RESTORE_DATASET:-1}"
    env_line OTBR_AUTO_CREATE_NETWORK "${OTBR_AUTO_CREATE_NETWORK:-0}"
    env_line ZIGBEE_DONGLE "${ZIGBEE_DONGLE:-/dev/ttyACM0}"
    env_line ZIGBEE2MQTT_BIND_ADDR "${ZIGBEE2MQTT_BIND_ADDR:-127.0.0.1}"
    env_line ZIGBEE2MQTT_PORT "${ZIGBEE2MQTT_PORT:-8080}"
    env_line NODE_RED_BIND_ADDR "${NODE_RED_BIND_ADDR:-127.0.0.1}"
    env_line NODE_RED_PORT "${NODE_RED_PORT:-1880}"
    env_line TS_AUTHKEY "${TS_AUTHKEY:-}"
    env_line TS_EXTRA_ARGS "${TS_EXTRA_ARGS:-}"
    env_line TS_USERSPACE "${TS_USERSPACE:-false}"
  } > "$temp_file"
  chmod 0600 "$temp_file"
  mv "$temp_file" "$ENV_OUTPUT"
  info "Configuration written to $ENV_OUTPUT"
}

apply_provisioning() {
  local confirmed
  [ "$MODE" != "config-only" ] || return 0
  [ "$DRY_RUN" -eq 0 ] || return 0

  ask_yes_no confirmed "Apply bootstrap and deploy selected services now" "yes"
  [ "$confirmed" = "yes" ] || die "Provisioning cancelled; .env was saved."

  hostnamectl set-hostname "$LISA_EDGE_HOSTNAME" || warn "Could not update the runtime hostname."
  "$EDGE_REPO/bootstrap/bootstrap.sh"
  install -d -m 0755 /var/lib/lisa-edge
  touch /var/lib/lisa-edge/provisioned
  rm -f /etc/update-motd.d/99-lisa-edge-provision
  systemctl disable lisa-first-boot.service >/dev/null 2>&1 || true
  info "Provisioning completed successfully."
}

main() {
  parse_args "$@"
  if [ "$(id -u)" -ne 0 ] && [ "$DRY_RUN" -ne 1 ]; then
    die "Run as root: sudo $0"
  fi

  echo "============================================================"
  echo " LISA Edge First-Boot Provisioning Wizard"
  echo "============================================================"

  load_environment
  choose_mode
  case "$MODE" in
    fresh|restore-usb|restore-path|config-only) ;;
    *) die "Unsupported mode: $MODE" ;;
  esac
  prepare_restore
  configure_global
  select_services
  run_service_wizards
  write_environment
  apply_provisioning

  if [ "$MODE" = "config-only" ]; then
    info "Configuration only. Run sudo ./bootstrap/bootstrap.sh when ready."
  fi
}

main "$@"
