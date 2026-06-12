# Matter

## What is Matter?

Matter is a smart home application protocol.

Matter allows devices from different vendors to work together.

Examples:

* Apple Home
* Google Home
* Home Assistant
* Homey
* SmartThings

can all communicate with the same Matter device.

---

## Matter is NOT a Network

Matter runs on top of existing networks.

Examples:

Matter over Wi-Fi

```text
Matter
  ↓
Wi-Fi
```

Matter over Ethernet

```text
Matter
  ↓
Ethernet
```

Matter over Thread

```text
Matter
  ↓
Thread
  ↓
Border Router
```

---

## Why Matter Matters

Before Matter:

* vendor lock-in
* incompatible ecosystems
* cloud dependencies

With Matter:

* local control
* interoperability
* standardized onboarding
* improved future compatibility

---

## Matter and LISA

LISA Edge does not replace Matter.

Instead, LISA Edge provides infrastructure services that support Matter deployments.

Examples:

* OTBR
* MQTT
* DNS helpers
* NTP
* VPN access
* Monitoring

LISA Brain interacts with devices through supported integrations while the Edge layer provides reliable local connectivity.

---

## Recommended Design

Matter devices:

```text
IoT VLAN
```

Controllers:

```text
Controller VLAN
```

Infrastructure:

```text
Service VLAN
```

Management:

```text
Management VLAN
```

Proper VLAN segmentation improves security while preserving local communication where required.
