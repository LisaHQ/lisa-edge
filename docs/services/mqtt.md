# MQTT

MQTT is the messaging backbone for LISA Edge.

Current implementation uses Eclipse Mosquitto.

## Purpose

MQTT can be used by:

- LISA Brain
- Home Assistant
- Zigbee2MQTT
- sensors and automations
- local integrations

## Configuration

Main files:

```text
compose/services/mqtt.yml
config/mqtt/mosquitto.conf
.env
```

Important environment values:

```env
MQTT_BIND_ADDR=192.168.20.10
MQTT_PORT=1883
MQTT_WS_PORT=9001
MQTT_USERNAME=lisa
MQTT_PASSWORD=change-this-password
```

The provisioning wizard generates a random password when the template value is
still present.

## Data

Mosquitto data is stored under:

```text
${DATA_ROOT}/docker/volumes/mosquitto
```

## Security

Recommended:

- Bind to service VLAN / infrastructure subnet IP when possible
- Do not expose MQTT to the public internet
- Use strong credentials
- Restrict cross-VLAN access by firewall rules
