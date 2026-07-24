# Deployment Validation

Use this after a fresh install, restore, service change, software update, or
hardware replacement.

Start with the stable operator checks:

```bash
sudo ./lisa-edge status
sudo ./lisa-edge health
```

Both commands must complete without hiding failed or unhealthy selected
services. `health` reports an overall `HEALTHY`, `DEGRADED`, or `FAILED`
result; `health --strict` also exits nonzero (3) on `DEGRADED` for
monitoring. Stable exit codes: 0 healthy (or degraded without `--strict`),
1 failed, 2 usage error, 3 degraded with `--strict`.

## Host

- [ ] host boots without keyboard, monitor, or manual firmware interaction
- [ ] expected Ubuntu or Debian release is installed
- [ ] hostname and timezone are correct
- [ ] Chrony reports working time synchronization
- [ ] SSH key authentication works
- [ ] password SSH is disabled when required
- [ ] temporary autoinstall passwordless sudo was removed unless explicitly kept
- [ ] Docker and the Compose plugin work after reboot
- [ ] `lisa-edge.service` starts the selected stack after reboot

## Storage

- [ ] production OS is on the intended disk
- [ ] active service data is not writing heavily to eMMC
- [ ] `DATA_ROOT` resolves to intended persistent storage
- [ ] storage mounts survive reboot
- [ ] backup destination is reachable
- [ ] mount enforcement prevents silent backup fallback to the root filesystem
- [ ] free space and log growth are acceptable

## Network and exposure

- [ ] host is on the intended VLAN or subnet
- [ ] DNS resolution and local service discovery behave as designed
- [ ] only required service ports are reachable from each network
- [ ] sensitive VLAN boundaries remain intact
- [ ] Tailscale is authenticated if selected
- [ ] dashboards are not publicly exposed

## Selected services

Use runtime status to identify the selected services:

```bash
sudo ./lisa-edge status
```

`./lisa-edge service list` shows all available selection keys, not the active
selection.

- [ ] MQTT accepts intended authenticated clients when selected
- [ ] Uptime Kuma is reachable only on its configured bind address when selected
- [ ] OTBR reports `child`, `router`, or `leader` when selected
- [ ] Home Assistant responds locally when selected
- [ ] Zigbee2MQTT detects its coordinator and reaches MQTT when selected
- [ ] Node-RED responds on its configured endpoint when selected
- [ ] all selected containers recover after a host reboot

NUT, DNS helpers, and reverse proxy are planned capabilities, not current
validation targets.

## Thread and Matter

When OTBR is selected:

- [ ] the RCP device uses a stable device path
- [ ] `sudo ./lisa-edge otbr status` shows the expected network name and role
- [ ] a current Thread Dataset backup (with `.sha256` sidecar) exists outside
      ephemeral container state
- [ ] dataset restore has been tested or rehearsed
- [ ] Matter devices remain functional after an OTBR restart

When Matter is selected:

- [ ] `sudo ./lisa-edge matter status` reports the expected listen address,
      fabric label, and Bluetooth availability
- [ ] `sudo ./lisa-edge matter thread status` reports no detectable Thread
      credential drift
- [ ] `sudo ./lisa-edge doctor matter-thread` ends with 0 failed checks
- [ ] the WebSocket port is reachable only from trusted controller networks

Health and drift checks compare identity fields (credential ID, network
name, extended PAN ID; channel/PAN ID/prefix where available from logs).
They CANNOT prove that the stored network key or PSKc match — the API never
returns them — and they cannot prove BLE end-to-end: a real BLE
commissioning of a test device on physical hardware is the only proof.

## Backup and restore

Create a real backup:

```bash
sudo ./lisa-edge backup
```

- [ ] archive, `.sha256`, and manifest are present
- [ ] archive is stored outside the production SSD failure domain
- [ ] backup includes `.env`, selected configuration, and persistent data
- [ ] retention behaves as configured
- [ ] containers return to healthy state after backup
- [ ] a restore has been tested on a safe target or replacement host

Backup creation alone does not prove recoverability.

## Diagnostics and recovery

```bash
sudo ./lisa-edge diagnostics
```

- [ ] the bundle is created successfully
- [ ] secret values are redacted before sharing
- [ ] production reinstall and restore paths do not depend on undocumented memory
- [ ] Rescue OS boots independently if it is part of the deployment model
- [ ] `./lisa-edge help` is available during recovery

## Production-ready decision

A node is not production-ready until:

- selected services pass health checks;
- remote administration preserves firewall boundaries;
- backups exist outside the node;
- restore has been exercised;
- critical services recover after reboot; and
- the operator knows which Git release and configuration produced the node.
