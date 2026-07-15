#!/usr/bin/env bash

LISA_DEFAULT_SERVICES="mqtt uptime-kuma"
LISA_ALL_SERVICES="mqtt uptime-kuma otbr vpn-tailscale ha zigbee2mqtt node-red"

lisa_selected_services() {
  local selected="${LISA_COMPOSE_SERVICES:-$LISA_DEFAULT_SERVICES}"
  if [ "$selected" = "all" ]; then
    selected="$LISA_ALL_SERVICES"
  fi
  printf '%s\n' "$selected"
}

lisa_has_service() {
  local wanted="$1"
  local service
  for service in $(lisa_selected_services); do
    [ "$service" = "$wanted" ] && return 0
  done
  return 1
}

lisa_validate_services() {
  local selected
  local service
  selected="$(lisa_selected_services)"

  if [ -z "$selected" ]; then
    echo "At least one LISA service must be selected." >&2
    return 1
  fi

  for service in $selected; do
    case " $LISA_ALL_SERVICES " in
      *" $service "*) ;;
      *)
        echo "Unknown LISA_COMPOSE_SERVICES entry: $service" >&2
        echo "Allowed: $LISA_ALL_SERVICES" >&2
        return 1
        ;;
    esac
  done

  if lisa_has_service zigbee2mqtt && ! lisa_has_service mqtt; then
    echo "zigbee2mqtt requires mqtt. Add mqtt to LISA_COMPOSE_SERVICES." >&2
    return 1
  fi
}

lisa_build_compose_files() {
  local repo_root="$1"
  local service
  local service_file
  local added=""

  lisa_validate_services
  LISA_COMPOSE_FILES=(-f "$repo_root/compose/docker-compose.yml")
  for service in $(lisa_selected_services); do
    case " $added " in *" $service "*) continue ;; esac
    service_file="$repo_root/compose/services/$service.yml"
    [ -f "$service_file" ] || {
      echo "Missing Compose service file: $service_file" >&2
      return 1
    }
    LISA_COMPOSE_FILES+=(-f "$service_file")
    added="${added:+$added }$service"
  done
}
