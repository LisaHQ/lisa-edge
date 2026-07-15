# Disaster Recovery

The preferred recovery source is a current format-v3 backup archive plus its
`.sha256` sidecar, stored outside the failed host.

## Replace a failed host

```text
Install Linux
  → clone lisa-edge
  → run sudo ./lisa-edge setup
  → choose restore from USB or mounted path
  → review restored configuration
  → bootstrap and deploy
  → health and functional verification
```

The setup wizard restores without starting containers, then prepares the host
and deploys the selected services. Format v3 backups are independent of the old
checkout path. Pin or review container image references before reconnecting a
restored production node.

After deployment:

```bash
sudo ./lisa-edge status
sudo ./lisa-edge health
sudo ./lisa-edge diagnostics
```

## Recover from the Rescue OS

When the production SSD cannot boot, use the independent Rescue OS:

```bash
sudo ./lisa-edge rescue disks
sudo ./lisa-edge rescue mount /dev/disk/by-id/PRODUCTION_PARTITION_ID
sudo ./lisa-edge rescue restore-backup /path/to/backup.tar.gz
```

`restore-backup` validates the standard LISA Edge archive. The separate
`restore-snapshot` command is only for an explicitly maintained raw filesystem
snapshot; it is not the output of `lisa-edge backup`.

## Critical state

| Service | Critical state |
|---|---|
| MQTT | `.env`, password database and retained data |
| OTBR | Active Operational Dataset |
| Tailscale | state directory or a valid re-authentication path |
| Uptime Kuma | monitor database |
| Home Assistant | configuration directory |
| Zigbee2MQTT | application data and coordinator information |
| Node-RED | flows, credentials and settings |

For dataset-only recovery, follow the
[OTBR recovery runbook](service-recovery/otbr.md). Practice both host replacement
and service verification before an incident.
