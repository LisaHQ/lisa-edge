# Service Catalog

LISA Edge runs lightweight infrastructure services. The canonical list of
deployable selection keys is generated from `services/registry.sh`:

```bash
./lisa-edge service list
```

Configure the complete service selection with `sudo ./lisa-edge setup` or edit
`LISA_COMPOSE_SERVICES` in `.env`, then apply it with:

```bash
sudo ./lisa-edge deploy
sudo ./lisa-edge health
```

`LISA_COMPOSE_SERVICES` is the whole selection, not an additive command. Keep
existing keys when adding a service.

## Implemented container services

| Service | Selection key | Default | Dependency | Reference |
|---|---|:---:|---|---|
| MQTT / Mosquitto | `mqtt` | Yes | — | [MQTT](mqtt.md) |
| Uptime Kuma | `uptime-kuma` | Yes | — | [Uptime Kuma](uptime-kuma.md) |
| OpenThread Border Router | `otbr` | No | Thread RCP hardware | [OTBR](otbr.md) |
| Tailscale | `vpn-tailscale` | No | `/dev/net/tun` | [Tailscale](vpn-tailscale.md) |
| Home Assistant | `ha` | No | — | [Home Assistant](home-assistant.md) |
| Zigbee2MQTT | `zigbee2mqtt` | No | `mqtt`, Zigbee coordinator | [Zigbee2MQTT](zigbee2mqtt.md) |
| Node-RED | `node-red` | No | — | [Node-RED](node-red.md) |

The implementation for each service is a vertical slice under `services/`
containing its Compose fragment, provisioning logic, source configuration and
service-specific recovery tools.

Home Assistant and Node-RED are supported for compact installations, but large
automation workloads normally belong on LISA Brain or another automation host.

## Implemented host capabilities

- [Chrony / NTP](ntp.md) is installed by host bootstrap and is not a Compose
  selection key.
- Avahi and IPv6 forwarding are prepared when OTBR is selected.
- Runtime and backup timers are operational infrastructure documented under
  [Operations](../operations/backup-restore.md), not selectable services.

## Planned capabilities

DNS helpers, NUT/UPS integration and a reverse proxy are design ideas only. See
[Planned Capabilities](../planned/README.md). Do not put their names in
`LISA_COMPOSE_SERVICES`.

## Usually external

Keep heavy compute, video analytics, large databases, long-term storage and
large observability stacks on dedicated systems. Examples include LLM/ASR/TTS
inference, Frigate, NAS workloads and high-write monitoring platforms.

Before adding any service, ask whether it improves local availability,
reliability or security enough to justify its resource use and recovery burden.
