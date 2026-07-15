# LISA Edge Documentation

LISA Edge is the local infrastructure layer of the LISA ecosystem.

Its purpose is to provide reliable local services that support smart-home platforms, connected devices, and future LISA Brain deployments.

LISA Edge focuses on:

- Connectivity
- Service discovery
- Messaging
- Monitoring
- Backup and recovery
- Secure remote access
- Infrastructure resilience

LISA Edge is intentionally lightweight.

It is not intended to become:

- An AI server
- A NAS
- A video analytics platform
- An all-in-one homelab server

## Recommended Reading Order

If you are new to LISA Edge, read the documentation in the following order:

1. [About LISA](architecture/01-lisa-ecosystem.md) --- An overview of the broader ecosystem
2. [Service Boundaries](architecture/02-service-boundaries.md)
3. [Deployment Patterns](architecture/03-deployment-patterns.md)
4. [Reference Deployment](architecture/04-reference-deployment.md)
5. Start with the Getting Started section.

---

## Getting Started

1. [Quick Start](getting-started/01-quick-start.md)
2. [Service Selection](getting-started/02-service-selection.md)
3. [USB Autoinstall Flow](getting-started/03-autoinstall-flow.md)
4. [Deployment Checklist](getting-started/04-deployment-checklist.md)
5. [Deployment Validation](getting-started/05-deployment-validation.md)
6. [First-Boot Provisioning](getting-started/06-first-boot-provisioning.md)

---

## Hardware

- [Hardware Model](hardware/reference-hardware.md)
- [Storage Model](hardware/storage-model.md)

---

## Networking

- [Network Model](networking/network-model.md)
- [UniFi Firewall Notes](networking/unifi-firewall.md)
- [Thread](networking/thread.md)
- [Matter](networking/matter.md)

---

## Security

- [Security Model](security/security-model.md)
- [Secrets](security/secrets.md)

---

## Services

- [Service Catalog](services/README.md)
- [MQTT](services/mqtt.md)
- [OTBR](services/otbr.md)
- [NUT](services/nut.md)
- [NTP](services/ntp.md)
- [DNS Helpers](services/dns.md)
- [Monitoring](services/monitoring.md)
- [Reverse Proxy](services/reverse-proxy.md)
- [Tailscale / VPN](services/vpn-tailscale.md)

---

## Operations

- [Diagnostics](operations/diagnostics.md)
- [Backup and Restore](operations/backup-restore.md)
- [Disaster Recovery](operations/disaster-recovery.md)
- [OTBR Recovery](operations/service-recovery/otbr.md)

---

## Design Principles

LISA Edge follows several core principles:

- Local-first operation
- Recovery over high availability
- Security by default
- Docker-first deployment
- Hardware independence
- Infrastructure as Code
- Reproducible deployments

Every service should improve one or more of:

- Availability
- Reliability
- Security
- Recoverability

If a service does not clearly contribute to those goals, it likely does not belong on LISA Edge.
