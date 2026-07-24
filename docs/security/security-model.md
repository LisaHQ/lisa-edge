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
- OTBR dataset backups and exports (`otbr dataset export` files are 0600 and
  contain the complete Thread credentials)
- Matter data backups (fabric credentials) and the Matter WebSocket API
- VPN state
- Home Assistant config
- Zigbee2MQTT keys
- NUT control access

## Matter WebSocket exposure

The Matter server's WebSocket API has no authentication and controls the
whole fabric. It binds to `MATTER_LISTEN_ADDRESS` (default `127.0.0.1`).
Rules:

- keep the default loopback bind unless a REMOTE Home Assistant needs it;
- when remote access is required, bind a specific trusted address and
  firewall `MATTER_SERVER_PORT` (default 5580) to the controller network;
- never bind `0.0.0.0` without an explicit firewall allowlist (deploy warns);
- never publish the port through a public reverse proxy.

CLI output is secret-safe by design: `otbr dataset show` redacts the network
key and PSKc, status/health/diagnostics never print credentials, and the
Thread dataset is never passed through process arguments or logs.

NUT is planned rather than currently selectable. Its control interface must be
treated as sensitive when the service is implemented.

## Network Segmentation

Use VLANs or separate subnets when available.

At minimum, separate:

- trusted users
- IoT devices
- cameras
- servers
- management
- guests

Use the [Deployment Checklist](../getting-started/04-deployment-checklist.md)
before exposing a new service and the
[Deployment Validation](../getting-started/05-deployment-validation.md) after
changes.
