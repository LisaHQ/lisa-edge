# Matter Server

Matter Server (matterjs-server) is the local Matter controller server for the
Matter fabric, a Matter.js-based drop-in replacement for python-matter-server
with the same WebSocket API. It is an optional service with selection key
`matter` (`matter-server` is accepted as an alias); the canonical owner is
[`services/matter-server/`](../../services/matter-server/README.md).

Home Assistant's Matter integration connects to it over WebSocket:

```text
ws://<edge-host>:5580/ws
```

The server also serves a web dashboard on the same port. With OTBR on the
same or another reachable host it enables Matter-over-Thread. Matter over
Wi-Fi and Ethernet work without OTBR.

## Requirements

- Host networking (mDNS multicast and direct IPv6 reachability to devices)
- IPv6 enabled on the host

Use `sudo ./lisa-edge setup` to select it. The wizard asks for
`MATTER_SERVER_PORT` (passed to the server as its listen port and used by
health checks), the Matter data backup directory and restore policy, and can
stage a data restore or fabric reset for the next deploy. Deploy and verify:

```bash
sudo ./lisa-edge deploy
sudo ./lisa-edge health
```

## Migration from python-matter-server

matterjs-server reads an existing python-matter-server store at
`${DATA_ROOT}/docker/volumes/matter-server/` and migrates it to its native
format on first start, so commissioned devices carry over without
re-commissioning. The migration is ONE-WAY: after matterjs-server has run,
the store can no longer be used by python-matter-server. Deploy detects the
image change and backs the store up first; that `pre-image-change` archive is
the only way back to the old server.

## Security

The WebSocket API has no authentication. Because the container uses host
networking, the port is reachable on every host address. Restrict it with
firewall or VLAN rules so only trusted controllers (for example the Home
Assistant host) can reach it. Never expose it beyond the local network.

## Fabric data safety

`${DATA_ROOT}/docker/volumes/matter-server/` holds the fabric credentials
and commissioned-device state. Treat it like the OTBR Thread dataset: losing
it requires re-commissioning every Matter device.

Protection mirrors the OTBR dataset tooling:

- On every deploy, `services/matter-server/data/init-or-restore.sh` runs
  before the containers start: it applies a staged wizard selection, backs
  the store up before a container image change, and restores
  `MATTER_DATA_LATEST` into an empty store when
  `MATTER_AUTO_RESTORE_DATA=1`.
- `lisa-matter-data-backup.timer` snapshots the store daily to
  `MATTER_DATA_BACKUP_DIR` (default `/srv/lisa-edge/backups/matter/`); the
  timer is enabled automatically when Matter is selected. The snapshot stops
  `lisa-matter` for a few seconds so the archive is consistent.
- `services/matter-server/data/backup.sh [description]`,
  `restore.sh [archive]` and `reset.sh` are the manual entry points. Restore
  and reset always preserve the current store as a `pre-restore` /
  `pre-reset` archive first; reset requires typing `RESET` and creates a
  fresh fabric on the next start.

The live store is also included in the standard full-stack backup
(`sudo ./lisa-edge backup`); keep a copy outside the edge host.

## Data detection during provisioning

The Matter wizard detects existing data backups. It scans the configured
backup directory (or a custom path you enter, such as a mounted USB or NAS
directory) for `*.tar.gz` archives, lists them newest first, and lets you
restore a selected backup, reset the fabric, or keep the current behavior.
The choice is staged as a one-shot `pending.matter-data.tar.gz` or
`pending.reset` marker inside `MATTER_DATA_BACKUP_DIR` and applied exactly
once by the next deploy; delete the marker to cancel before deploying. Deploy
backs up the active store before applying any staged change.

See the [Matter recovery runbook](../operations/service-recovery/matter.md)
before hardware migration or disaster recovery.

Related background: [Matter](../networking/matter.md),
[Thread](../networking/thread.md) and [OTBR](otbr.md).
