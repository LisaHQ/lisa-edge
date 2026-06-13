# Reference Deployments

This document provides example deployment models for LISA Edge.

---

# Single Host Smart Home

```text
Internet
    │
    ▼
Router
    │
    ▼
LISA Edge
    │
 ┌──┴──┐
 │     │
MQTT  OTBR
 │     │
 ▼     ▼
Automation
Matter / Thread
```

Suitable for:

* Apartments
* Small homes

---

# Smart Home with LISA AI Brain

```text
                ┌───────────────┐
                │ LISA AI Brain │
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
     │          │
     │          ▼
     ▼     Matter Devices
Automation (Matter / Thread / IoT Devices)
```

Recommended architecture.

LISA Brain performs AI workloads.

LISA Edge provides infrastructure services.

---

# Homelab

```text
             Internet
                 │
                 ▼
             Firewall
                 │
                 ▼
             LISA Edge
                 │
        ┌────────┼───────────┐
        │        │           │
        ▼        ▼           ▼
       VPN     Proxy     Monitoring
        │
        ▼
Internal Services
```

Suitable for:

* Self-hosting
* Small lab environments

---

# Future High Availability

```text
           ┌──────────────┐
           │ Backup Store │
           └───────┬──────┘
                   │
                   ▼
     ┌───────────────────────────┐
     │        LISA Edge A        │
     └─────────────┬─────────────┘
                   │
                   ▼
     ┌───────────────────────────┐
     │        LISA Edge B        │
     └───────────────────────────┘
```

Current releases focus on:

* Backup
* Restore
* Fast recovery

instead of complex clustering.

---

# Design Philosophy

LISA Edge is:

* Linux-first
* Docker-first
* Local-first
* Hardware agnostic

LISA Edge is not:

* A NAS
* An AI server
* A Kubernetes platform

Heavy workloads belong on dedicated systems.

LISA Edge focuses on reliable infrastructure services.
