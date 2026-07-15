# LISA Edge

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
![Documentation](https://img.shields.io/badge/Documentation-Stable-brightgreen)
![Architecture](https://img.shields.io/badge/Architecture-Docker-blue)
![Platform](https://img.shields.io/badge/Platform-Linux-blue)
![Shell](https://img.shields.io/badge/Shell-Bash-blue)

**LISA Edge** is the infrastructure layer of the **[LISA](https://github.com/LisaHQ)** ecosystem.

> **LISA** stands for **Local Intelligent System Assistant**.  
> It's a local-first AI ecosystem designed to become a true digital caretaker for intelligent environments.  
> Its long-term goal is to understand context, coordinate smart-home devices, support natural interaction, and continue operating even when cloud services are unavailable.

LISA Edge is **not** the AI brain. It's the foundation that keeps the environment connected, recoverable, and locally available.  
LISA Edge provides the local connectivity, messaging, networking, monitoring, backup, and operational services that allow the broader LISA platform to run reliably.

For a broader overview, see:

- [LISA Ecosystem](docs/architecture/01-lisa-ecosystem.md)
- [Service Boundaries](docs/architecture/02-service-boundaries.md)

---

## Why LISA Edge Exists

AI systems should not depend entirely on cloud connectivity, fragile integrations, or a single overloaded host running every service.

LISA Edge exists to provide a resilient, secure, local-first infrastructure foundation for the LISA ecosystem.

It focuses on:

- local availability
- infrastructure services
- secure connectivity
- service discovery
- edge automation support
- network integration
- backup and recovery
- operational resilience

If cloud services become unavailable, LISA Edge should continue supporting critical local infrastructure.

---

## What LISA Edge Provides

The current implementation provides:

- Thread Border Router services
- Matter-over-Thread support
- MQTT messaging
- host time synchronization with Chrony
- VPN-first remote administration
- health monitoring
- backup jobs
- restore procedures
- infrastructure automation

DNS helpers, NUT and reverse proxy deployment are planned services. They are
documented for architecture planning but are not selectable Compose services yet.

---

## What LISA Edge Is Not

LISA Edge should not become an all-in-one server.

Avoid placing heavy workloads here unless explicitly justified.

LISA Edge is generally **not**:

- LISA Brain
- an LLM inference server
- a speech processing server
- a memory or agent reasoning system
- a primary NAS
- a video analytics server
- a large database host
- a heavy camera processing node

Those workloads belong on dedicated LISA Brain, NAS, Vision, or compute systems.

See:

- [Service Boundaries](docs/architecture/02-service-boundaries.md)

---

## LISA Ecosystem

```text
         Internet
            │                            ┌──────────────────────────────────────┐
            │                            │  Future Compute & Vision Services    │
            │                            │  (optional ecosystem components)     │
            │                            │--------------------------------------│
            │                            │ LISA Core / LISA Vision / LISA Voice │
            │                            └──────────────────────────────────────┘
            │                                                ▲
            │                                                │
            ▼                                                ▼
┌────────────────────────┐                     ┌───────────────────────────┐
│ Network Infrastructure │               ┌───► │         LISA Brain        │ ◄───┐
│------------------------│               │     │---------------------------│     │
│    VLANs / Firewall    │               │     │  AI Reasoning / Voice     │     │
└───────────┬────────────┘               │     │  Memory / Agents / Tools  │     │
            │                            │     └───────────────────────────┘     │
            │                            ▼                                       ▼
            │               ┌─────────────────────────┐             ┌─────────────────────────┐
            └─────────────► │        LISA Edge        ├───────────► │   Smart Home Platform   │
            ↑               │-------------------------│             │-------------------------│
            |               │ OTBR / MQTT / NUT / VPN │             │ Homey                   │
            |               │ DNS / NTP / Monitoring  │             │ Home Assistant          │
            |               │ Backup / Restore        │             │ Future Controllers...   │
            |               └─────────────────────────┘             └────────────┬────────────┘
            |                                                                    ▼
            |                                                       ┌─────────────────────────┐
            |                                                       │ Smart Home Environment  │
            |                                                       │    (Matter / Thread)    │
            |                                                       │-------------------------│
            |                                                       │ Local IoT Devices       │
            |                                                       │-------------------------│
            └------------ Cloud Services (Optional) ------------►   │ Cloud IoT Devices       │
                                                                    └─────────────────────────┘
```

LISA Edge supports intelligence.  
It does not replace it.

---

## Supported Platforms

LISA Edge is hardware-independent.

Any Linux system capable of running Docker may be used.

Examples:

- ZimaBoard 2
- Raspberry Pi 4 / 5
- Intel NUC
- Mini PC
- generic x86-64 server
- NAS Docker host
- virtual machine
- cloud VM

Hardware is a deployment detail, not an architectural requirement.

---

## Reference Platform

The current reference deployment target is:

- ZimaBoard 2 1664
- 16 GB RAM
- 64 GB eMMC
- UPS available
- Samsung SATA SSD
- Mellanox MCX312A-XCBT
- future 10GbE networking

Recommended storage model:

| Storage                | Purpose                                                                     |
|------------------------|-----------------------------------------------------------------------------|
| eMMC                   | Rescue OS, recovery environment, emergency maintenance                      |
| SATA SSD               | Primary Ubuntu Server installation, Docker volumes, persistent service data |
| NAS / External Storage | Backups, archives, restore images                                           |

### Design Rule

LISA Edge should boot from SSD.  
Avoid heavy writes to eMMC.

The onboard eMMC should be preserved as an independent rescue and recovery environment whenever practical.  
This provides an additional recovery path if the primary SSD installation becomes unavailable.

See:

- [Reference Deployment](docs/architecture/04-reference-deployment.md)

---

## LISA Edge Services

| Service       | Status      | Purpose                                |
|---------------|-------------|----------------------------------------|
| MQTT          | Implemented | Local event messaging                  |
| Uptime Kuma   | Implemented | Lightweight monitoring                 |
| Backup timer  | Implemented | Host-level backup and restore workflow |
| OTBR          | Implemented | Thread Border Router                   |
| Tailscale     | Implemented | Secure remote administration           |
| Chrony        | Implemented | Host time synchronization              |
| NUT           | Planned     | UPS monitoring and graceful shutdown   |
| DNS helpers   | Planned     | Local name resolution                  |
| Reverse proxy | Planned     | Internal HTTPS and service routing     |

See:

- [Service Catalog](docs/services/README.md)

---

## Thread and Matter

LISA Edge supports Matter-over-Thread deployments through OpenThread Border Router.

The Thread Dataset is critical infrastructure.

Losing the dataset may require re-pairing Matter-over-Thread devices.

LISA Edge documentation includes:

- dataset backup
- dataset restore
- migration workflows
- disaster recovery procedures

See:

- [Thread](docs/networking/thread.md)
- [Matter](docs/networking/matter.md)
- [OTBR](docs/services/otbr.md)
- [OTBR Recovery](docs/operations/service-recovery/otbr.md)

---

## Repository Layout

The repository is organized by deployment lifecycle rather than programming
language:

| Path | Responsibility |
| --- | --- |
| [`bootstrap/`](bootstrap/README.md) | Host packages, hardening, Docker, storage, and initial deployment |
| [`compose/`](compose/README.md) | Base Compose model and service fragments |
| [`config/`](config/README.md) | Version-controlled source configuration copied into runtime storage |
| [`provisioning/`](provisioning/README.md) | First-boot wizard and service-specific configuration |
| [`scripts/`](scripts/README.md) | Production runtime, backup, restore, health, and maintenance commands |
| [`tools/`](tools/README.md) | Developer, build, and repository-validation utilities |
| [`test/`](test/README.md) | Unit, security, and integration tests |
| [`systemd/`](systemd/README.md) | Production runtime and backup units |
| [`recovery/`](recovery/README.md) | Independent rescue environment and recovery workflows |
| [`usb-installer/`](usb-installer/README.md) | Production and rescue USB installation assets |
| [`docs/`](docs/README.md) | Architecture, deployment, security, and operations documentation |

Runtime secrets and generated `.env` files are intentionally excluded from Git.

---

## Getting Started

New users should begin with the Documentation Index before attempting deployment.  
Start here:

1. [Documentation Index](docs/README.md)
2. [Quick Start](docs/getting-started/01-quick-start.md)
3. [Service Selection](docs/getting-started/02-service-selection.md)
4. [USB Autoinstall Flow](docs/getting-started/03-autoinstall-flow.md)
5. [Deployment Checklist](docs/getting-started/04-deployment-checklist.md)
6. [Deployment Validation](docs/getting-started/05-deployment-validation.md)
7. [First-Boot Provisioning](docs/getting-started/06-first-boot-provisioning.md)

Basic flow:

```bash
sudo git clone https://github.com/LisaHQ/lisa-edge.git /opt/lisa-edge
cd /opt/lisa-edge
sudo ./provisioning/lisa-first-boot.sh --mode config-only
sudo ./bootstrap/bootstrap.sh
sudo ./scripts/healthcheck.sh
```

---

## Security Principles

LISA Edge follows a security-first approach.

Recommended defaults:

- VPN-first administration
- SSH key authentication
- no public admin dashboards
- minimal exposed ports
- VLAN segmentation
- firewall allow-lists
- least privilege
- secrets outside Git
- regular backups
- restore testing

High-sensitivity networks such as alarm, access-control, camera, and management VLANs should receive additional protection.

See:

- [Security Model](docs/security/security-model.md)
- [Network Model](docs/networking/network-model.md)
- [UniFi Firewall Notes](docs/networking/unifi-firewall.md)

---

## Backup and Recovery

LISA Edge prioritizes recovery over unnecessary clustering.

Priority order:

1. backup
2. restore
3. reliability
4. failover

Critical services should provide:

- backup procedure
- restore procedure
- health checks
- restart policies
- exportable configuration

A failed LISA Edge host should be replaceable from source-controlled configuration and backups.

See:

- [Backup and Restore](docs/operations/backup-restore.md)
- [Disaster Recovery](docs/operations/disaster-recovery.md)

---

## Roadmap

See:

- [Roadmap](docs/roadmap.md)

---

## Design Philosophy

LISA Edge is:

- Linux-first
- Docker-first
- local-first
- security-conscious
- hardware-independent
- recovery-focused
- practical immutable infrastructure

Infrastructure exists to support intelligence, not replace it.

---

## License

This repository is licensed under **Apache 2.0**.

See [LICENSE](LICENSE) for details.

Other LISA ecosystem repositories, services, models, datasets, or future components may use different licenses.

Copyright (c) 2026 **[LisaHQ](https://lisahq.io)**
