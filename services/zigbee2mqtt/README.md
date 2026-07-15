# Zigbee2MQTT

- Selection key: `zigbee2mqtt`
- Enabled by default: no
- Dependency: `mqtt`
- Container: `lisa-zigbee2mqtt`

Configure the coordinator path, bind address and UI port with
`sudo ./lisa-edge setup`. Prefer `/dev/serial/by-id/...` over a changing tty
name. The wizard adds MQTT when required.

```bash
sudo ./lisa-edge deploy
sudo ./lisa-edge health
```

Persistent application and coordinator state lives at
`${DATA_ROOT}/docker/volumes/zigbee2mqtt/` and is included in full backups.

Owned files: `compose.yml` and `provision.sh`. See
[operator reference](../../docs/services/zigbee2mqtt.md).
