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

| Service          | Edge | Brain | Smart Home | NAS | Vision |
|------------------|------|-------|------------|-----|--------|
| MQTT             | ✓    |       |            |     |        |
| OTBR             | ✓    |       |            |     |        |
| NUT              | ✓    |       |            |     |        |
| DNS Helpers      | ✓    |       |            |     |        |
| Reverse Proxy    | ✓    |       |            |     |        |
| VPN              | ✓    |       |            |     |        |
| NTP              | ✓    |       |            |     |        |
| LLM              |      | ✓     |            |     |        |
| ASR              |      | ✓     |            |     |        |
| TTS              |      | ✓     |            |     |        |
| Homey            |      |       | ✓          |     |        |
| Home Assistant   |      |       | ✓          |     |        |
| Frigate          |      |       |            |     | ✓      |
| Object Detection |      |       |            |     | ✓      |
| Backups          |      |       |            | ✓   |        |

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

Recommended services:

* OTBR
* MQTT
* NUT
* DNS helpers
* NTP
* Reverse Proxy
* Tailscale
* Uptime Kuma
* Health checks
* Backup jobs

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
✓ NUT
✓ Tailscale
✓ Reverse Proxy
✓ Uptime Kuma
✓ DNS Helpers
✓ NTP
✓ Backup Automation
✓ Health Monitoring
```

These services support the ecosystem.

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
