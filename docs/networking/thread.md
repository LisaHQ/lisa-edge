# Thread Networking

## What is Thread?

Thread is a low-power IPv6 mesh networking protocol designed for smart home devices.

Thread is:

* wireless
* self-healing
* local-first
* IPv6-native

Thread is NOT:

* Wi-Fi
* Zigbee
* Bluetooth

---

## Thread Components

A Thread network typically contains:

### Border Router

Connects Thread devices to the IP network.

Examples:

* OTBR
* Home Assistant OTBR
* Apple Border Router
* Google Border Router

### Router

Extends the mesh network.

Usually powered devices.

Examples:

* Smart plugs
* Wall switches
* Light controllers

### End Device

Battery-powered devices.

Examples:

* Sensors
* Contact sensors
* Motion detectors

---

## Thread vs Zigbee

| Feature                  | Thread | Zigbee          |
| ------------------------ | ------ | --------------- |
| IPv6                     | Yes    | No              |
| Matter support           | Native | Through bridges |
| Self-healing             | Yes    | Yes             |
| Vendor independence      | High   | Medium          |
| Future ecosystem support | Strong | Declining       |

---

## Thread and Matter

Thread and Matter are not the same thing.

Thread = transport network

Matter = application protocol

Examples:

Matter over Wi-Fi

```text
Matter
  ↓
Wi-Fi
```

Matter over Thread

```text
Matter
  ↓
Thread
  ↓
Border Router (OTBR)
  ↓
Ethernet
```

---

## Why LISA Uses Thread

Benefits:

* Local-first communication
* Low power consumption → Better battery life
* Reduced cloud dependency
* Self-healing mesh network
* IPv6 native
* Vendor-neutral ecosystem
* Strong Matter support

Thread is the preferred networking technology for future Matter deployments.

## Border Router Choices

Examples:

- LISA Edge OTBR
- Home Assistant OTBR
- Apple Border Router
- Google Border Router

Only one Border Router is required to start a Thread network.

Multiple Border Routers may coexist and provide redundancy.