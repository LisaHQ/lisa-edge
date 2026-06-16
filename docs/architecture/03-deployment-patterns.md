# Deployment Patterns

This document describes common deployment patterns for LISA Edge.

These patterns are examples, not requirements.

LISA Edge is designed to remain hardware-independent and portable across a wide range of environments.

The purpose of this document is to illustrate how LISA Edge can be deployed while maintaining the project's core principles:

* Local-first operation
* Security by default
* Infrastructure simplicity
* Recovery-focused architecture
* Hardware independence

---

# Pattern 1: Single Host Smart Home

The simplest deployment model.

```text
                     Internet
                         │
                         ▼
                 Router / Gateway
                         │
                         ▼
                 ┌───────────────┐
                 │   LISA Edge   │
                 └───────┬───────┘
                         │
                      ┌──┴──┐
                      │     │
                      ▼     ▼
                    MQTT  OTBR
                      │     │
                      ▼     ▼
                    Automation
              Matter / Thread Devices
```

Suitable for:

* Apartments
* Small homes
* Testing environments
* Early-stage deployments

Characteristics:

* Lowest complexity
* Minimal hardware requirements
* Fast deployment
* Easy maintenance

This pattern is ideal for users who only require infrastructure services and smart-home connectivity.

---

# Pattern 2: LISA Edge + LISA Brain

Recommended long-term architecture.

```text
                 ┌───────────────┐
                 │  LISA Brain   │
                 └───────┬───────┘
                         │
                         ▼
                 ┌───────────────┐
                 │   LISA Edge   │
                 └───────┬───────┘
                         │
      ┌──────────┬───────┼───────┬──────────┐
      │          │       │       │          │
      ▼          ▼       ▼       ▼          ▼
    MQTT       OTBR     NUT     VPN     Monitoring
      │
      ▼
Matter / Thread Devices
```

Responsibilities:

LISA Edge:

* Connectivity
* Messaging
* Service discovery
* Monitoring
* Backup automation
* Secure remote access

LISA Brain:

* AI reasoning
* Voice interaction
* Memory
* Agent workflows
* Smart-home orchestration

This deployment keeps infrastructure separate from intelligence.

This is the preferred architecture for most production environments.

---

# Pattern 3: Smart Home Platform Integration

LISA Edge can coexist with existing smart-home controllers.

```text
                 ┌───────────────┐
                 │  LISA Brain   │
                 └───────┬───────┘
                         │
                         ▼
                 ┌───────────────┐
                 │   LISA Edge   │
                 └───────┬───────┘
                         │
            ┌────────────┬────────────┐
            │            │            │
            ▼            ▼            ▼
          Homey   Home Assistant   MQTT
            │            │
            └──────┬─────┘
                   ▼
      Matter / Thread / IoT Devices
```

Suitable for:

* Existing Homey deployments
* Existing Home Assistant deployments
* Mixed-controller environments

LISA Edge provides infrastructure services.

Smart-home platforms manage devices and automations.

LISA Brain provides intelligence.

---

# Pattern 4: Typical LISA Edge Deployment

Current validation environment for LISA Edge.

```text
                      Internet
                          │
                          ▼
                     UDM-Pro-Max
                          │
                          ▼
                  ┌───────────────┐
                  │   LISA Edge   │
                  │ (ZimaBoard 2) │
                  └───────┬───────┘
                          │
             ┌─────┬──────┬──────┬───────┐
             │     │      │      │       │
             ▼     ▼      ▼      ▼       ▼
            OTBR  MQTT   NUT    VPN  Monitoring
             │
             ▼
      Thread Network
             │
             ▼
      Matter Devices
          (Homey)
             │
  ┌──────┬───┴───┬──────┐
Matter Zigbee  Wi-Fi  Z-Wave
  └──────┴───┬───┴──────┘
             ▼
     Smart Home Devices
```

Characteristics:

* Local-first
* Docker-based
* Recovery-focused
* VLAN-aware
* VPN-first administration

This deployment is used to validate documentation, installation procedures, backup workflows, and operational behavior.

---

# Pattern 5: Homelab Infrastructure

For users operating a larger self-hosted environment.

```text
                     Internet
                         │
                         ▼
                Firewall / Gateway
                         │
                         ▼
                 ┌───────────────┐
                 │   LISA Edge   │
                 └───────┬───────┘
                         │
          ┌─────────┬─────────┬─────────┐
          │         │         │         │
          ▼         ▼         ▼         ▼
         VPN     Reverse   Monitoring  OTBR
                  Proxy
```

Additional services may exist elsewhere:

* NAS
* LISA Brain
* Home Assistant
* Vision Server

LISA Edge should remain focused on infrastructure responsibilities.

---

# Pattern 6: Recovery-Oriented Expansion

Future expansion should prioritize recovery rather than clustering.

```text
                 Backup Repository
                         │
                         ▼
              ┌─────────────────────┐
              │    Configuration    │
              │       Backups       │
              └──────────┬──────────┘
                         │
                         ▼
                   LISA Edge Host
```

Recommended investments:

* Backup automation
* Restore testing
* Configuration version control
* Infrastructure as Code
* Portable Compose deployments

The preferred recovery order is:

1. Backup
2. Restore
3. Reliability
4. Failover

LISA Edge intentionally avoids unnecessary clustering complexity.

---

# Choosing a Deployment Pattern

For most users:

```text
Pattern 2
LISA Edge + LISA Brain
```

is the recommended architecture.

For users focused primarily on smart-home infrastructure:

```text
Pattern 1
Single Host Smart Home
```

may be sufficient.

For larger environments:

```text
Pattern 3 + Pattern 5
```

provides a clean separation between infrastructure, automation, and intelligence.

---

# Design Philosophy

Deployment patterns should follow the same principles as the rest of the LISA ecosystem:

* Local-first
* Secure by default
* Recovery-focused
* Docker-first
* Hardware-independent
* Easy to rebuild
* Easy to migrate

LISA Edge exists to provide reliable infrastructure services.

It is not intended to become:

* A NAS
* An AI server
* A Kubernetes platform
* A video analytics platform

Heavy workloads should remain on dedicated systems whenever practical.

## Related Documentation

- [LISA Ecosystem](01-lisa-ecosystem.md)
- [Service Boundaries](02-service-boundaries.md)
- [Reference Deployment](04-reference-deployment.md)
