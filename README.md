# LISA Edge

LISA Edge is the lightweight edge infrastructure platform for the LISA Smart Home ecosystem.

It targets ZimaBoard 2 running Ubuntu Server on SSD, while the internal eMMC is kept as a Rescue OS for recovery and reinstall operations.

## GitHub description

Infrastructure-as-Code repository for the LISA Smart Home Edge Platform. Provides unattended Ubuntu provisioning, automated bootstrap, Docker service deployment, backup/recovery workflows, VPN connectivity, MQTT, Thread Border Router, NUT integration and production-ready edge services running on ZimaBoard 2.

## Design goals

- Production OS on SSD
- eMMC reserved for Rescue OS
- USB autoinstall support
- Fully reproducible bootstrap
- Docker Compose based services
- Lightweight services only
- VLAN-aware deployment
- Backup and restore first
- No public admin dashboards
- VPN-first administration

## Target hardware

- ZimaBoard 2 1664
- 16GB RAM
- SSD for production OS and service data
- eMMC for Rescue OS
- UPS available
- Optional dual-port 10GbE NIC
- Thread RCP radio such as nRF52840/ZBT-2 flashed as RCP

## First boot flow

```text
USB autoinstall
  -> install Ubuntu Server to SSD
  -> clone this repo into /opt/lisa-edge
  -> run bootstrap/bootstrap.sh
  -> configure host
  -> install Docker
  -> create data directories
  -> deploy service stack
  -> enable systemd deploy unit
  -> run healthcheck
```

## Quick start after OS install

```bash
sudo git clone https://github.com/YOUR_ORG/lisa-edge.git /opt/lisa-edge
cd /opt/lisa-edge
sudo cp .env.example .env
sudo nano .env
sudo ./bootstrap/bootstrap.sh
```

## Services

Core services:

- Mosquitto MQTT
- Uptime Kuma
- NUT client/server placeholder
- Traefik internal reverse proxy placeholder

Optional profile:

- OpenThread Border Router

Thread Border Router is intentionally isolated into a profile because it depends on the real radio path and backbone network interface.

## Storage policy

```text
SSD:
  /opt/lisa-edge
  /srv/lisa-edge
  Docker
  service volumes

EMMC:
  Rescue OS only
```

## Deploy

```bash
sudo ./scripts/deploy.sh
```

With Thread Border Router:

```bash
sudo LISA_COMPOSE_PROFILES=otbr ./scripts/deploy.sh
```
