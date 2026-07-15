# Reference Deployment

This document describes the reference deployment used to validate LISA Edge.

The reference deployment is not a hard requirement.  
LISA Edge is hardware-independent and should remain portable across Linux hosts, virtual machines, and future hardware.

The automated host bootstrap currently supports Ubuntu and Debian. Portability
to other Linux distributions refers to the architecture and Compose model, not
an automated installation guarantee.

---

## Purpose

The reference deployment exists to provide a practical baseline for:

- testing installation flows
- validating Docker Compose services
- documenting network assumptions
- verifying backup and restore procedures
- confirming operational behavior after power loss or hardware replacement

Architecture should not depend on this specific hardware.

---

## Current Reference Hardware

The current primary reference target is:

- ZimaBoard 2 1664
- 16 GB RAM
- 64 GB eMMC
- Samsung SATA SSD for the production OS, Docker data, and persistent volumes
- UPS available
- Mellanox MCX312A-XCBT for future 10GbE networking

These details are deployment context, not architectural requirements.

---

## Current Reference Environment

Current environment:

- UDM-Pro-Max
- USW-Pro-Max-16-PoE
- U7-XGS (x2)
- VLAN architecture documented separately

---

## Storage Layout

Recommended layout:

| Storage                | Purpose                                                                     |
|------------------------|-----------------------------------------------------------------------------|
| eMMC                   | Rescue OS, recovery environment, emergency maintenance                      |
| SATA SSD               | Primary Ubuntu Server installation, Docker volumes, persistent service data |
| NAS / External Storage | Backups, archives, restore images                                           |

Avoid heavy writes to eMMC.

High-write workloads should use SSD or external storage.

---

## Service Placement

Implemented lightweight services and capabilities include:

- OTBR
- MQTT
- NTP / Chrony
- Tailscale VPN
- Uptime Kuma
- optional Home Assistant, Zigbee2MQTT, and Node-RED service slices
- backup and restore helpers
- health checks

Architecturally suitable but planned services include NUT, DNS helpers, and a
reverse proxy. They are not current selectable deployment targets.

Heavy workloads should run elsewhere:

- LLM inference
- ASR / TTS processing
- video analytics
- object detection
- large databases
- NAS workloads
- media storage

See also:

- [Service Boundaries](02-service-boundaries.md)

---

## Network Placement

LISA Edge should be placed on a trusted infrastructure or service VLAN.

Recommended principles:

- VPN-first administration
- SSH key authentication
- no public admin dashboards
- firewall allow-lists between VLANs
- least-privilege service exposure
- explicit access rules for sensitive networks

High-sensitivity networks such as alarm, access-control, camera, and management VLANs should receive additional protection.

---

## Recovery Expectations

A reference deployment should be recoverable from documented source-controlled configuration and backups.

Minimum recovery expectations:

- host can be reinstalled from documented bootstrap flow
- Docker services can be redeployed from Compose files
- secrets are restored from a secure backup process
- persistent volumes are restored from backup
- Thread dataset backup and restore are documented
- health checks confirm service readiness

The goal is not clustering for its own sake.

Priority order:

1. backup
2. restore
3. reliability
4. failover

---

## Validation Checklist

Before treating a deployment as production-ready, verify:

- [ ] host boots without keyboard or monitor
- [ ] SSH works with key authentication
- [ ] Docker services start after reboot
- [ ] persistent data is on SSD or external storage
- [ ] backups run successfully
- [ ] at least one restore test has been performed
- [ ] OTBR dataset backup exists if Thread is enabled
- [ ] monitoring detects failed services
- [ ] VPN access works without exposing admin dashboards publicly
- [ ] firewall rules preserve VLAN boundaries

---

## Non-Goals

The reference deployment should not turn LISA Edge into an all-in-one server.

Avoid adding services only because the hardware can run them.

Every service should answer:

- Does this improve local availability?
- Does this improve reliability?
- Does this improve security?
- Is the operational complexity justified?
- Can it be backed up and restored cleanly?

## Related Documentation

- [LISA Ecosystem](01-lisa-ecosystem.md)
- [Service Boundaries](02-service-boundaries.md)
- [Deployment Patterns](03-deployment-patterns.md)
