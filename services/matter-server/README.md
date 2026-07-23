# Matter Server

- Selection key: `matter`
- Accepted aliases: `matter-server`
- Enabled by default: no
- Container: `lisa-matter`

Matter Server (matterjs-server, the Matter.js-based drop-in replacement for
python-matter-server) is the local Matter controller server. Home Assistant
connects to it over WebSocket at `ws://<edge-host>:5580/ws`. Combined with
OTBR it supports Matter-over-Thread; Matter over Wi-Fi and Ethernet work
without OTBR.

It uses host networking because commissioning depends on mDNS multicast and
direct IPv6 reachability. The WebSocket API is unauthenticated: keep port
5580 restricted to trusted controller networks with firewall or VLAN rules.

BLE commissioning (new Thread devices receive their network credentials over
Bluetooth) needs a Bluetooth adapter on the host. The container runs as root
with `NET_RAW`/`NET_ADMIN` because the kernel ignores HCI commands from
unprivileged users, and the image is pinned to a release tag because
`:stable` can serve nightly matter.js alpha builds. See the operator
reference for the full BLE requirements and troubleshooting.

Fabric credentials and commissioned-device state live at
`${DATA_ROOT}/docker/volumes/matter-server/`. This data is critical: losing
it requires re-commissioning every Matter device. matterjs-server migrates
existing python-matter-server storage found there in place; the migration is
one-way, and deploy backs the store up before the image change.

Data tools under `data/` back the store up, restore it, reset the fabric or
initialize it on deploy, mirroring the OTBR dataset protection. The wizard
detects existing Matter data backups (default directory or a custom path) and
can stage a selected backup or a fabric reset as a one-shot pending marker
that the next deploy applies; deploy backs up the active store first.
Production should keep `MATTER_AUTO_RESTORE_DATA=1`. The units in `systemd/`
schedule daily data backups when Matter is selected; a scheduled backup stops
`lisa-matter` for the few seconds the snapshot takes. The live store is also
included in the standard `sudo ./lisa-edge backup` archive.

Select it with `sudo ./lisa-edge setup`, then use `sudo ./lisa-edge deploy`
and `sudo ./lisa-edge health`. When OTBR is also selected, health warns if
the server's stored Thread credentials drift from OTBR's active dataset;
`sudo ./lisa-edge matter sync-dataset` re-syncs them.

Owned files: `compose.yml`, `provision.sh`, `data/` and `systemd/`. See the
[operator reference](../../docs/services/matter-server.md) and
[recovery runbook](../../docs/operations/service-recovery/matter.md).
