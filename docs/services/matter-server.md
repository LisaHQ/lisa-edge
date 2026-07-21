# Matter Server

Matter Server (python-matter-server) is the local Matter controller server
for the Matter fabric. It is an optional service with selection key `matter`
(`matter-server` is accepted as an alias); the canonical owner is
[`services/matter-server/`](../../services/matter-server/README.md).

Home Assistant's Matter integration connects to it over WebSocket:

```text
ws://<edge-host>:5580/ws
```

With OTBR on the same or another reachable host it enables Matter-over-Thread.
Matter over Wi-Fi and Ethernet work without OTBR.

## Requirements

- Host networking (mDNS multicast and direct IPv6 reachability to devices)
- IPv6 enabled on the host
- Optional: a Bluetooth adapter for Bluetooth-assisted commissioning
  (`/run/dbus` is mounted read-only for this)

Use `sudo ./lisa-edge setup` to select it. The wizard asks only for
`MATTER_SERVER_PORT`, which is used by health checks; the server itself
listens on 5580 by default. Deploy and verify:

```bash
sudo ./lisa-edge deploy
sudo ./lisa-edge health
```

## Security

The WebSocket API has no authentication. Because the container uses host
networking, port 5580 is reachable on every host address. Restrict it with
firewall or VLAN rules so only trusted controllers (for example the Home
Assistant host) can reach it. Never expose it beyond the local network.

## Fabric data safety

`${DATA_ROOT}/docker/volumes/matter-server/` holds the fabric credentials
and commissioned-device state. Treat it like the OTBR Thread dataset: losing
it requires re-commissioning every Matter device. It is included in the
standard full-stack backup (`sudo ./lisa-edge backup`); keep a copy outside
the edge host.

Related background: [Matter](../networking/matter.md),
[Thread](../networking/thread.md) and [OTBR](otbr.md).
