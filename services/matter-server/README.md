# Matter Server

- Selection key: `matter`
- Accepted aliases: `matter-server`
- Enabled by default: no
- Container: `lisa-matter`

Matter Server (python-matter-server) is the local Matter controller server.
Home Assistant connects to it over WebSocket at `ws://<edge-host>:5580/ws`.
Combined with OTBR it supports Matter-over-Thread; Matter over Wi-Fi and
Ethernet work without OTBR.

It uses host networking because commissioning depends on mDNS multicast and
direct IPv6 reachability. The WebSocket API is unauthenticated: keep port
5580 restricted to trusted controller networks with firewall or VLAN rules.

Fabric credentials and commissioned-device state live at
`${DATA_ROOT}/docker/volumes/matter-server/`. This data is critical: losing
it requires re-commissioning every Matter device. It is included in the
standard `sudo ./lisa-edge backup` archive.

Select it with `sudo ./lisa-edge setup`, then use `sudo ./lisa-edge deploy`
and `sudo ./lisa-edge health`.

Owned files: `compose.yml` and `provision.sh`. See
[operator reference](../../docs/services/matter-server.md).
