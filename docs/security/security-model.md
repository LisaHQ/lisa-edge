# Security Model

LISA Edge should be treated as infrastructure.

## Principles

- VPN-first administration
- No public admin dashboards
- SSH key authentication
- Disable SSH password login
- Minimal exposed ports
- Firewall allowlists
- Secrets outside Git
- Encrypted backups for sensitive data
- Temporary bootstrap-only passwordless sudo
- Immutable container image digests for production releases

The Ubuntu autoinstall account receives passwordless sudo only so unattended
bootstrap can start. Bootstrap removes `/etc/sudoers.d/90-lisa-admin` after a
usable local password is confirmed, unless the operator explicitly enables the
documented emergency override.

## Sensitive Services

Protect:

- MQTT
- OTBR dataset backups
- VPN state
- Home Assistant config
- Zigbee2MQTT keys
- NUT control access

## Network Segmentation

Use VLANs or separate subnets when available.

At minimum, separate:

- trusted users
- IoT devices
- cameras
- servers
- management
- guests
