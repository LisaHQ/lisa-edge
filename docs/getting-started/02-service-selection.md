# Service Selection Guide

LISA Edge is intentionally modular.

Deploy only the services you actually need.

Run `sudo lisa-edge-provision` and select one service, multiple services, or
`all`. Each selected service starts its own configuration wizard. Zigbee2MQTT
automatically adds its MQTT dependency.

---

# MQTT

Purpose:

* Messaging
* Event distribution
* Automation integration

Recommended for:

* Home Assistant
* Homey
* Node-RED
* LISA AI Brain

Enable if:

```text
You need a local event bus.
```

---

# OTBR

Purpose:

* Thread Border Router

Required for:

* Matter over Thread devices

Examples:

* Eve
* Nanoleaf
* Future Matter sensors

Enable if:

```text
You have Thread devices.
```

---

# NUT (planned, not selectable yet)

Purpose:

* UPS monitoring
* Graceful shutdown

Planned for deployments where:

```text
You have a UPS.
```

---

# Tailscale

Purpose:

* Secure remote access

Enable if:

```text
You need remote administration.
```

---

# Reverse Proxy (planned, not selectable yet)

Purpose:

* Unified access point
* TLS termination
* Service routing

Planned for deployments where:

```text
Multiple web services are deployed.
```

---

# Uptime Kuma

Purpose:

* Monitoring
* Notifications

Enable if:

```text
You want service health monitoring.
```

---

# Common Deployment Profiles

## Smart Home

Recommended:

* MQTT
* OTBR
* NUT (when implemented)

---

## Homelab

Recommended:

* MQTT
* Tailscale
* Reverse Proxy (when implemented)
* Uptime Kuma

---

## LISA AI Deployment

Recommended:

* MQTT
* NUT (when implemented)
* Tailscale
* Reverse Proxy (when implemented)

Optional:

* OTBR

Depending on Matter usage.

---

# Start Small

Begin with the minimum required services.

Additional services can be deployed later without rebuilding the host.
