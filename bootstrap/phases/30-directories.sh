#!/usr/bin/env bash
set -euo pipefail

# Storage layout
# eMMC (64GB)
# └─ Rescue OS
#    ├─ Ubuntu Server minimal
#    ├─ SSH
#    ├─ Network tools
#    ├─ Recovery scripts
#    └─ Reinstall USB support
#
# SSD (500GB / 1TB)
# └─ Production OS
#    ├─ Ubuntu Server
#    ├─ Docker
#    ├─ All LISA Edge services
#    ├─ Data volumes
#    └─ Backups cache
# .\
# └─ srv/lisa-edge/
#    ├─ backups
#    ├─ data
#    │  ├─ tailscale
#    │  ├─ zigbee2mqtt
#    ├─ docker/
#    │  ├─ volumes/
#    │  │  ├─ mosquitto/
#    │  │  │  ├─ config/
#    │  │  │  ├─ data/
#    │  │  │  └─ log/
#    │  │  ├─ uptime-kuma/
#    │  │  ├─ homeassistant/
#    │  │  ├─ node-red/
#    │  │  ├─ tailscale/
#    │  │  ├─ zigbee2mqtt/
#    │  │  └─ otbr/
#    │  └─ config/
#    ├─ logs/
#    ├─ state/
#    └─ secrets/

DATA_ROOT="${DATA_ROOT:-/srv/lisa-edge}"

mkdir -p "$DATA_ROOT"/{backups,data,docker}
mkdir -p "$DATA_ROOT"/docker/{volumes,config}
install -d -m 0755 "$DATA_ROOT"/docker/volumes/{mosquitto,uptime-kuma,homeassistant,node-red,tailscale,zigbee2mqtt,otbr}
install -d -m 0755 "$DATA_ROOT"/docker/volumes/mosquitto/{config,data,log}
install -d -m 0755 "$DATA_ROOT"/{logs,state}
install -d -m 0700 "$DATA_ROOT"/secrets

# Keep local service logs small. Long-term logs should go to NAS or central logging later.
if [ -d /etc/systemd/journald.conf.d ]; then
  true
else
  mkdir -p /etc/systemd/journald.conf.d
fi
cat >/etc/systemd/journald.conf.d/lisa-edge.conf <<'JOURNALD'
[Journal]
SystemMaxUse=256M
RuntimeMaxUse=128M
MaxRetentionSec=7day
JOURNALD
systemctl restart systemd-journald || true

echo "Directories created under $DATA_ROOT"
