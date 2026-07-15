# LISA Edge Documentation

Use the root operator command for normal work:

```bash
./lisa-edge help
```

This documentation explains decisions, safety constraints, and detailed
workflows. The CLI and current implementation remain the source of truth for
available commands and services.

## Find the task you need

| Task | Start here |
| --- | --- |
| Install or set up a host | [Quick Start](getting-started/01-quick-start.md) |
| Decide which services to run | [Service Selection](getting-started/02-service-selection.md) |
| Build production or rescue media | [USB Autoinstall Flow](getting-started/03-autoinstall-flow.md) |
| Review prerequisites before changing a host | [Deployment Checklist](getting-started/04-deployment-checklist.md) |
| Prove a deployment is ready | [Deployment Validation](getting-started/05-deployment-validation.md) |
| Run fresh, restore, or configuration-only provisioning | [First-Boot Provisioning](getting-started/06-first-boot-provisioning.md) |
| Diagnose a production host | [Diagnostics](operations/diagnostics.md) |
| Back up or restore | [Backup and Restore](operations/backup-restore.md) |
| Recover a failed production system | [Disaster Recovery](operations/disaster-recovery.md) |

## Recommended first deployment

1. Read [Quick Start](getting-started/01-quick-start.md) and choose manual,
   production USB, or restore.
2. Review [Service Selection](getting-started/02-service-selection.md).
3. Complete the [Deployment Checklist](getting-started/04-deployment-checklist.md).
4. Run `sudo ./lisa-edge setup`.
5. Complete [Deployment Validation](getting-started/05-deployment-validation.md).

USB users should read the autoinstall guide before writing media. Restore users
should read the first-boot provisioning guide before selecting an archive.

## Current implementation status

Implemented and selectable:

- MQTT
- Uptime Kuma
- OpenThread Border Router
- Tailscale
- Home Assistant
- Zigbee2MQTT
- Node-RED

Implemented host-level capabilities include Chrony, bootstrap, systemd runtime,
health checks, diagnostics, full-stack backup/restore, OTBR dataset protection,
and the independent Rescue OS workflow.

Planned and not selectable:

- [NUT / UPS integration](planned/services/nut.md)
- [DNS helpers](planned/services/dns.md)
- [Reverse proxy](planned/services/reverse-proxy.md)

Do not use a planned document as a deployment instruction.

## Architecture

- [LISA Ecosystem](architecture/01-lisa-ecosystem.md)
- [Service Boundaries](architecture/02-service-boundaries.md)
- [Deployment Patterns](architecture/03-deployment-patterns.md)
- [Reference Deployment](architecture/04-reference-deployment.md)

## Hardware and storage

- [Hardware Model](hardware/reference-hardware.md)
- [Storage Model](hardware/storage-model.md)

The architecture is portable across Linux systems. Automated host bootstrap is
currently supported on Ubuntu and Debian; other distributions require a manual
deployment path.

## Networking

- [Network Model](networking/network-model.md)
- [UniFi Firewall Notes](networking/unifi-firewall.md)
- [Thread](networking/thread.md)
- [Matter](networking/matter.md)

## Security

- [Security Model](security/security-model.md)
- [Secrets](security/secrets.md)

## Implemented services

- [Service Catalog](services/README.md)
- [MQTT](services/mqtt.md)
- [OTBR](services/otbr.md)
- [NTP / Chrony](services/ntp.md)
- [Uptime Kuma](services/uptime-kuma.md)
- [Tailscale / VPN](services/vpn-tailscale.md)
- [Home Assistant](services/home-assistant.md)
- [Zigbee2MQTT](services/zigbee2mqtt.md)
- [Node-RED](services/node-red.md)
- [Monitoring model](services/monitoring.md)

## Operations

- [Diagnostics](operations/diagnostics.md)
- [Backup and Restore](operations/backup-restore.md)
- [Disaster Recovery](operations/disaster-recovery.md)
- [OTBR Recovery](operations/service-recovery/otbr.md)

## Project planning and history

- [Roadmap](roadmap.md)
- [Planned documentation](planned/README.md)
- [Documentation archive](archive/README.md)

Archived files are historical context only and are never operational sources of
truth.
