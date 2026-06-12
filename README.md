# LISA Edge

Lightweight edge infrastructure services for smart homes, Matter, Thread, and local-first automation.

LISA Edge provides the infrastructure layer that supports the larger LISA ecosystem.

It focuses on reliability, local operation, disaster recovery, and infrastructure services rather than AI workloads.

---

# Goals

LISA Edge exists to provide:

* Thread Border Router (OTBR)
* MQTT messaging
* NUT (UPS integration)
* DNS and service helpers
* Reverse proxy
* VPN endpoints
* Monitoring and health checks
* Backup and recovery automation

LISA Edge is intentionally lightweight.

Heavy workloads belong on dedicated servers:

* LLM inference
* Speech processing
* Computer vision
* Databases
* NAS workloads

---

# Architecture

```text
Internet
    │
    ▼
Network Gateway (UniFi)
    │
    ▼
LISA Edge
    │
    ├── OTBR
    ├── MQTT
    ├── NUT
    ├── VPN
    ├── DNS Helpers
    └── Monitoring
    │
    ▼
Matter / Thread / IoT Devices
```

---

# Supported Platforms

LISA Edge is hardware agnostic.

Any Linux system capable of running Docker may be used.

Examples:

* ZimaBoard 2
* Raspberry Pi 4
* Raspberry Pi 5
* Intel NUC
* Mini PC
* Generic x86-64 server
* Virtual Machine

---

# Reference Platform

The recommended reference platform is:

* ZimaBoard 2

Reasons:

* Low power consumption
* SATA support
* PCIe expansion
* Reliable Docker performance
* Compact deployment footprint

All documentation and testing are primarily validated against this platform.

---

# Core Services

| Service       | Purpose                  |
|---------------| ------------------------ |
| OTBR          | Thread Border Router     |
| MQTT          | Event messaging          |
| NUT           | UPS integration          |
| Reverse Proxy | Internal service routing |
| Tailscale     | Remote access            |
| Uptime Kuma   | Health monitoring        |

---

# Thread and Matter

LISA Edge supports Matter-over-Thread deployments through OpenThread Border Router (OTBR).

Important:

The Thread Dataset is critical infrastructure.

Loss of the dataset may require re-pairing Matter-over-Thread devices.

LISA Edge includes:

* Dataset backup
* Dataset restore
* Migration support
* Disaster recovery automation

See:

* docs/THREAD.md
* docs/MATTER.md
* docs/OTBR.md
* docs/OTBR-RECOVERY.md

---

# Deployment

Clone repository:

```bash
git clone https://github.com/huysrc/lisa-edge.git
cd lisa-edge
```

Configure environment:

```bash
cp .env.example .env
```

Deploy:

```bash
./scripts/deploy.sh
```

---

# Disaster Recovery

Critical services should be recoverable from backup.

LISA Edge emphasizes:

* Config as code
* Docker Compose
* Portable volumes
* Automated backups
* Minimal manual intervention

---

# Security Principles

* Local-first
* VPN-first administration
* SSH key authentication
* Minimal exposed ports
* VLAN segmentation
* Secrets outside Git
* Backup critical datasets

---

# License

MIT License
