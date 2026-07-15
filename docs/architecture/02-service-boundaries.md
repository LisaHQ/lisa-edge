# Service Boundaries

This document defines where services should run within the LISA ecosystem.

Its purpose is to prevent infrastructure sprawl and keep deployments maintainable.

---

# Overview

The LISA ecosystem is divided into logical layers.

```text
          Internet
             │
             ▼
   Network Infrastructure
             │
             ▼
         LISA Edge
             │
             ▼
         LISA Brain
             │
             ▼
   Automation / Smart Home
```

Each layer has a specific responsibility.

This table describes architectural ownership as well as repository status.
`Planned` means the service fits the Edge boundary but is not selectable today.

| Service | Edge | Brain | Smart Home | NAS | Vision | Repository status |
| --- | --- | --- | --- | --- | --- | --- |
| MQTT | ✓ | | | | | Implemented |
| OTBR | ✓ | | | | | Implemented |
| Uptime Kuma | ✓ | | | | | Implemented |
| Tailscale | ✓ | | | | | Implemented |
| Zigbee2MQTT | ✓ | | ✓ | | | Implemented |
| Node-RED | ✓ | | ✓ | | | Implemented |
| Home Assistant | optional | | ✓ | | | Implemented, optional co-location |
| NUT | ✓ | | | | | Planned |
| DNS helpers | ✓ | | | | | Planned |
| Reverse proxy | ✓ | | | | | Planned |
| NTP / Chrony | ✓ | | | | | Implemented on host |
| LLM | | ✓ | | | | Outside this repository |
| ASR / TTS | | ✓ | | | | Outside this repository |
| Homey | | | ✓ | | | External platform |
| Frigate / object detection | | | | | ✓ | Outside this repository |
| Backup destination | | | | ✓ | | External storage recommended |

---

# LISA Edge

Purpose:

Infrastructure services.

LISA Edge should remain lightweight, reliable, and easy to recover.

Typical hardware:

* ZimaBoard
* Raspberry Pi
* Intel NUC
* Mini PC
* Virtual Machine

Implemented services and capabilities:

* OTBR
* MQTT
* Tailscale
* Uptime Kuma
* Home Assistant
* Zigbee2MQTT
* Node-RED
* Chrony
* Health checks
* Backup jobs

Planned:

* NUT
* DNS helpers
* Reverse proxy

Characteristics:

* Low CPU usage
* Low memory usage
* Small storage footprint
* Fast recovery

---

# LISA Brain

Purpose:

AI and automation orchestration.

Recommended services:

* LLMs
* Tool orchestration
* Voice assistants
* Workflow engines
* Home automation logic
* Device intelligence

Examples:

* OpenAI integrations
* Local LLMs
* Speech-to-text
* Text-to-speech
* Agent workflows

Characteristics:

* CPU intensive
* Memory intensive
* Frequently updated

LISA Brain should remain separate from LISA Edge whenever possible.

---

# NAS

Purpose:

Storage.

Recommended services:

* Backups
* Media storage
* Archive storage
* Shared files
* Snapshot repositories

Examples:

* Synology
* TrueNAS
* Unraid

Do not use LISA Edge as primary storage.

---

# Vision Server

Purpose:

Video and camera processing.

Recommended services:

* Frigate
* Object detection
* Face recognition
* Camera analytics
* Video AI

Characteristics:

* GPU intensive
* Storage intensive

Vision workloads should not run on LISA Edge.

---

# Database Servers

Purpose:

Data persistence.

Examples:

* PostgreSQL
* MariaDB
* InfluxDB
* TimescaleDB

Small deployments may run lightweight databases on LISA Edge.

Large deployments should use dedicated infrastructure.

---

# What SHOULD Run on LISA Edge

Recommended:

```text
✓ OTBR
✓ MQTT
✓ Tailscale
✓ Uptime Kuma
✓ Chrony
✓ Backup Automation
✓ Health Monitoring
```

Planned Edge services:

```text
◇ NUT
◇ DNS Helpers
◇ Reverse Proxy
```

Run `./lisa-edge service list` before treating any service as deployable.

---

# What MAY Run on LISA Edge

Acceptable for small deployments:

```text
△ Small PostgreSQL
△ Small MariaDB
△ Lightweight APIs
△ Configuration Services
△ Small Dashboards
```

Evaluate resource usage carefully.

---

# What SHOULD NOT Run on LISA Edge

Avoid:

```text
✗ Large LLMs
✗ GPU inference
✗ Video transcoding
✗ Frigate with many cameras
✗ Vector databases
✗ NAS workloads
✗ Large monitoring stacks
✗ Heavy analytics
```

These services belong elsewhere.

---

# Recovery Philosophy

LISA Edge should be easy to replace.

Preferred characteristics:

* Infrastructure as code
* Docker Compose
* Externalized configuration
* Portable volumes
* Automated backups

A failed LISA Edge host should be recoverable within minutes.

---

# Design Principles

LISA Edge is:

* Linux-first
* Docker-first
* Local-first
* Hardware agnostic
* Recovery focused

LISA Edge is infrastructure.

It is not intended to become an all-in-one server.

## Related Documentation

- [LISA Ecosystem](01-lisa-ecosystem.md)
- [Deployment Patterns](03-deployment-patterns.md)
- [Reference Deployment](04-reference-deployment.md)
