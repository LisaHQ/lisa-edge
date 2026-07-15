# LISA Edge

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/Automated%20Setup-Ubuntu%20%7C%20Debian-blue)
![Runtime](https://img.shields.io/badge/Runtime-Docker%20Compose-blue)

LISA Edge is the lightweight local-infrastructure layer of the LISA ecosystem.
It provides connectivity, messaging, monitoring, secure remote access, backup,
and recovery services. AI reasoning, large storage, and video processing belong
on other LISA systems.

The stable operator interface is the root command:

```bash
./lisa-edge help
```

You should not need to know where an implementation script lives.

## Start by task

| I need to… | Command |
| --- | --- |
| Set up a new or restored host | `sudo ./lisa-edge setup` |
| Write or update `.env` only | `sudo ./lisa-edge configure` |
| Bootstrap an already configured host | `sudo ./lisa-edge bootstrap` |
| Start or reconcile services | `sudo ./lisa-edge deploy` |
| Stop services | `sudo ./lisa-edge stop` |
| Update Git and selected images | `sudo ./lisa-edge update` |
| See runtime state | `sudo ./lisa-edge status` |
| Run readiness checks | `sudo ./lisa-edge health` |
| List selectable services | `./lisa-edge service list` |
| Create a backup | `sudo ./lisa-edge backup` |
| Restore a backup | `sudo ./lisa-edge restore <archive>` |
| Collect diagnostics | `sudo ./lisa-edge diagnostics` |
| Prepare a production USB | `sudo ./lisa-edge usb production <mount-path>` |
| Prepare a rescue USB | `sudo ./lisa-edge usb rescue <mount-path>` |
| Work from the Rescue OS | `sudo ./lisa-edge rescue <command>` |

Run `./lisa-edge help` for the complete command map.

## Fastest fresh install

The automated host bootstrap supports Ubuntu Server and Debian. Other Linux
distributions may run the Compose services, but their host preparation is a
manual, unsupported path today.

```bash
sudo git clone https://github.com/LisaHQ/lisa-edge.git /opt/lisa-edge
cd /opt/lisa-edge
sudo ./lisa-edge setup
sudo ./lisa-edge health
```

`setup` starts the provisioning wizard. A fresh setup writes `.env`, asks for
service-specific settings, and offers to bootstrap and deploy the host.

For a production USB install or an existing backup, choose the matching path:

- [USB Autoinstall Flow](docs/getting-started/03-autoinstall-flow.md)
- [First-Boot and Restore Provisioning](docs/getting-started/06-first-boot-provisioning.md)

## Current capabilities

Selectable services:

- MQTT
- Uptime Kuma
- OpenThread Border Router
- Tailscale
- Home Assistant
- Zigbee2MQTT
- Node-RED

Zigbee2MQTT automatically selects MQTT. Chrony time synchronization, host
bootstrap, health checks, backup/restore, systemd runtime units, and rescue
tooling are host-level capabilities rather than selectable Compose services.

Planned but not selectable today:

- NUT / UPS integration
- DNS helpers
- reverse proxy

See [Service Selection](docs/getting-started/02-service-selection.md) for when to
enable each implemented service.

## Deployment model

The reference deployment uses:

| Storage | Role |
| --- | --- |
| eMMC | Minimal independent Rescue OS |
| SSD | Production OS, Docker, and persistent service data |
| NAS or external storage | Backups and restore media |

The architecture remains hardware-independent. The current reference platform
is a ZimaBoard 2, but a suitable Ubuntu or Debian host, VM, Raspberry Pi, NUC,
or mini PC can be used when its CPU architecture supports the selected images.

## Repository map

| Path | Go here when… |
| --- | --- |
| [`install/usb/`](install/usb/README.md) | preparing production or rescue installation media |
| [`install/provisioning/`](install/provisioning/README.md) | changing first-boot and site-specific setup |
| [`install/bootstrap/`](install/bootstrap/README.md) | changing host packages, hardening, Docker, or storage preparation |
| [`services/`](services/README.md) | changing one service's Compose, config, provisioning, or preparation |
| `ops/deploy/` | changing deploy, stop, update, health, status, or runtime systemd behavior |
| `ops/backup-restore/` | changing full-stack backup, restore, archive validation, or timers |
| `ops/diagnostics/` | changing production diagnostic collection |
| [`rescue/`](rescue/README.md) | maintaining the independent Rescue OS and disaster-recovery tools |
| [`docs/`](docs/README.md) | understanding architecture, security, networking, or detailed procedures |
| [`tools/`](tools/README.md) | building assets or validating the repository |
| [`tests/`](tests/README.md) | running unit, security, and integration tests |

Former layouts (`scripts/`, `bootstrap/`, `provisioning/`, `usb-installer/`,
`recovery/`, `compose/`, `config/`, `systemd/`) have been removed. All
automation goes through the root CLI and the canonical paths above.

## Safety rules

- Autoinstall can erase a disk. Match the target by serial or an explicitly
  reviewed model; never guess a device name.
- Keep `.env` and runtime secrets outside Git and mode them `0600`.
- Treat backup archives as sensitive because they may contain credentials.
- Require checksum sidecars and review restored image references before deploy.
- Keep administration VPN-first and avoid public dashboards.
- Test restore, not just backup creation.

## Documentation

Start with:

1. [Quick Start](docs/getting-started/01-quick-start.md)
2. [Service Selection](docs/getting-started/02-service-selection.md)
3. [Deployment Checklist](docs/getting-started/04-deployment-checklist.md)
4. [Deployment Validation](docs/getting-started/05-deployment-validation.md)

Architecture, networking, hardware, security, operations, roadmap, and archived
material are indexed in [docs/README.md](docs/README.md).

## License

Licensed under the [Apache License 2.0](LICENSE).

Copyright (c) 2026 [LisaHQ](https://lisahq.io)
