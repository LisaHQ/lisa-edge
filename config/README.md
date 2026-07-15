# Service Configuration

This directory contains version-controlled source configuration that deployment
scripts copy into persistent runtime storage under `DATA_ROOT`.

Currently, `mqtt/mosquitto.conf` is consumed by `scripts/prepare-mqtt.sh` before
the Mosquitto container starts. Runtime-generated files such as password
databases do not belong here.

Only add a configuration file when a script or Compose service consumes it.
Document the consumer in this README and keep secrets outside Git.
