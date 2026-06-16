# LISA Ecosystem

LISA stands for **Local Intelligent System Assistant**.

LISA is an open, local-first AI ecosystem designed to become a true digital caretaker for intelligent environments.

The goal of LISA is to create an intelligent assistant capable of understanding context, interacting naturally, coordinating smart-home devices, and operating reliably even when cloud services are unavailable.

Unlike traditional voice assistants and cloud-centric platforms, LISA is designed around local control, privacy, reliability, and long-term ownership.

LISA is not merely a chatbot or voice assistant.

It is an ecosystem intended to understand, monitor, reason about, and interact with an environment while remaining under the owner's control.

---

# Vision

LISA aims to become an AI-powered household assistant capable of supporting everyday life inside a smart home.

Potential capabilities include:

* Natural voice conversations
* Smart-home control
* Context-aware automation
* Multi-room awareness
* Presence and occupancy understanding
* Proactive notifications
* Energy optimization
* Security monitoring
* Household assistance
* Long-term memory and personalization
* Multi-device orchestration

The long-term objective is to provide a local-first assistant that continues operating even when cloud services are unavailable.

---

# Core Principles

## Local First

Critical functionality should continue operating without Internet connectivity whenever practical.

## Privacy First

Personal data should remain under the owner's control.

## Vendor Independence

The ecosystem should avoid unnecessary dependence on proprietary platforms.

## Reliability

Infrastructure should continue functioning during outages, maintenance, hardware replacement, and service failures.

## Recoverability

Systems should be easy to rebuild, restore, and migrate.

## Extensibility

New services, protocols, devices, and AI capabilities should be easy to integrate over time.

---

# Ecosystem Architecture

The LISA ecosystem is composed of multiple logical layers.

```text
          Internet
             │                               ┌────────────────────────────────────┐
             │                               │  Future Compute & Vision Services  │
             │                               │  (optional ecosystem components)   │
             │                               └────────────────────────────────────┘
             │                                                   ▲
             │                                                   │
             ▼                                                   ▼
 ┌────────────────────────┐                       ┌───────────────────────────┐
 │ Network Infrastructure │                ┌────► │         LISA Brain        │ ◄──────┐
 │------------------------│                │      │---------------------------│        │
 │    VLANs / Firewall    │                │      │  AI Reasoning / Voice     │        │
 └───────────┬────────────┘                │      │  Memory / Agents / Tools  │        │
             │                             │      └───────────────────────────┘        │
             │                             ▼                                           ▼
             │                ┌─────────────────────────┐                ┌────────────────────────────┐
             └──────────────► │        LISA Edge        ├──────────────► │    Smart Home Platforms    │
             ↑                │-------------------------│                │----------------------------│
             |                │ OTBR / MQTT / NUT / VPN │                │ Homey                      │
             |                │ DNS / NTP / Monitoring  │                │ Home Assistant             │
             |                │ Backup / Restore        │                │ Future Controllers...      │
             |                └─────────────────────────┘                └──────────────┬─────────────┘
             |                                                                          ▼
             |                                                             ┌────────────────────────┐
             |                                                             │ Smart Home Environment │
             |                                                             │    (Matter / Thread)   │
             |                                                             │------------------------│
             |                                                             │ Local IoT Devices      │
             |                                                             │------------------------│
             └--------------- Cloud Services (Optional) ---------------►   │ Cloud IoT Devices      │
                                                                           └────────────────────────┘
```

Each layer has a dedicated responsibility.

Keeping those responsibilities separate helps maintain reliability, security, and operational simplicity.

---

# Network Infrastructure

The foundation of the ecosystem.

Typical responsibilities include:

* Routing
* Firewall policies
* VLAN segmentation
* Wi-Fi infrastructure
* Physical connectivity
* Internet access
* Security boundaries

Examples:

* UniFi Gateway
* UniFi Switches
* UniFi Access Points
* Future multi-site connectivity

This layer provides connectivity for everything above it.

---

# LISA Edge

LISA Edge is the infrastructure layer of the LISA ecosystem.

Its purpose is to provide reliable local services that support both LISA Brain and smart-home operations.

LISA Edge focuses on:

* Connectivity
* Messaging
* Service discovery
* Monitoring
* Backup automation
* Recovery tooling
* Secure remote access
* Infrastructure resilience

Examples of services commonly associated with LISA Edge include:

* Thread Border Router
* MQTT
* VPN services
* Reverse Proxy
* NTP
* DNS helpers
* Monitoring
* Health checks
* Backup automation

LISA Edge should continue operating even if cloud services become unavailable.

LISA Edge is intentionally lightweight.

It is not intended to become the primary AI server, NAS, or vision-processing platform.

---

# LISA Brain

LISA Brain provides intelligence.

Typical responsibilities may include:

* LLM inference
* Voice interaction
* Long-term memory
* Agent workflows
* Tool orchestration
* Planning
* Reasoning
* Smart-home coordination
* Decision-making

Examples:

* Local LLMs
* Speech-to-text systems
* Text-to-speech systems
* Agent frameworks
* AI orchestration engines

LISA Brain consumes infrastructure services provided by LISA Edge.

Whenever possible, LISA Brain should remain logically separate from LISA Edge.

---

# Smart Home Ecosystem

The smart-home layer contains devices, controllers, and automation platforms.

Examples include:

* Matter devices
* Thread devices
* Zigbee devices
* Wi-Fi IoT devices
* Homey
* Home Assistant
* IP-connected devices

This layer represents the physical environment that LISA ultimately interacts with.

LISA Edge provides infrastructure support.

LISA Brain provides intelligence.

The smart-home layer provides devices and integrations.

---

# Future Compute and Vision Services

Some workloads do not naturally belong on LISA Edge.

Examples include:

* Camera analytics
* Object detection
* Face recognition
* GPU inference
* AI compute clusters
* Distributed processing
* Multi-site services

These workloads may eventually run on dedicated systems designed specifically for compute-intensive tasks.

---

# Architectural Philosophy

LISA follows several architectural principles.

## Clear Service Boundaries

Each layer should have a clearly defined responsibility.

Infrastructure should remain separate from intelligence whenever practical.

## Recovery Over Complexity

Systems should be easy to restore after failures.

Backup and recovery are generally more valuable than unnecessary clustering.

## Hardware Independence

The architecture should not depend on a specific device.

Services should remain portable across:

* ZimaBoard
* Raspberry Pi
* Mini PCs
* NUCs
* Virtual Machines
* Cloud instances

## Local Autonomy

The ecosystem should continue providing core functionality during Internet outages whenever possible.

---

# Design Rule

When evaluating whether a service belongs on LISA Edge, ask:

* Is it infrastructure?
* Is it lightweight?
* Does it improve local availability?
* Does it improve connectivity?
* Does it improve reliability?
* Does it improve recoverability?
* Can it be backed up and restored cleanly?
* Does it preserve security boundaries?

If the answer is mostly yes, it likely belongs on LISA Edge.

If the service performs heavy AI inference, large-scale storage, video analytics, or compute-intensive processing, it likely belongs elsewhere.

For detailed placement guidance, see:

* service-boundaries.md

---

# Current Status

LISA is an evolving long-term project rather than a finished product.

The ecosystem is designed to grow gradually while maintaining a strong focus on:

* Local operation
* Privacy
* Security
* Reliability
* Recoverability
* Hardware independence
* Vendor independence

The ultimate goal is a resilient, local-first AI ecosystem that remains useful, maintainable, and under the owner's control.

## Related Documentation

- [Service Boundaries](02-service-boundaries.md)
- [Deployment Patterns](03-deployment-patterns.md)
- [Reference Deployment](04-reference-deployment.md)
