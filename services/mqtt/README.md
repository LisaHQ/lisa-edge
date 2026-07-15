# MQTT / Mosquitto

- Selection key: `mqtt`
- Enabled by default: yes
- Container: `lisa-mqtt`
- Ports: `MQTT_PORT` 1883 and `MQTT_WS_PORT` 9001

Select and configure it with `sudo ./lisa-edge setup`. Deployment refuses the
template password, prepares Mosquitto configuration and credentials, starts the
container, then verifies readiness:

```bash
sudo ./lisa-edge deploy
sudo ./lisa-edge health
```

Persistent state lives below `${DATA_ROOT}/docker/volumes/mosquitto/` and is
included in full backups. Keep `MQTT_BIND_ADDR` on localhost or a trusted service
network and never expose the broker directly to the internet.

Owned files: `compose.yml`, `config/mosquitto.conf`, `prepare.sh` and
`provision.sh`. See [operator reference](../../docs/services/mqtt.md).
