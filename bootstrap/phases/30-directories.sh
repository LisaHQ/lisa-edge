#!/usr/bin/env bash
set -euo pipefail
DATA_ROOT="${DATA_ROOT:-/srv/lisa-edge}"
install -d -m 0755 "$DATA_ROOT"/{data,backups,logs,docker/volumes}
install -d -m 0755 "$DATA_ROOT/docker/volumes"/{mosquitto/{config,data,log},uptime-kuma,otbr,nut,traefik}
