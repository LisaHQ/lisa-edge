# Network Model

LISA Edge should live on a trusted infrastructure network.

Recommended placement:

- Management access on a management VLAN or admin subnet
- Service access on a service VLAN or infrastructure subnet
- No public admin dashboards
- Remote administration through VPN

## Firewall Philosophy

Default deny between sensitive networks.

Allow only required flows:

```text
Controllers  → LISA Edge: MQTT, DNS, NTP, OTBR services as needed
Admin/VPN    → LISA Edge: SSH and dashboards
IoT devices  → LISA Edge: only required service ports
Internet     → LISA Edge dashboards: deny
```

## Discovery Protocols

Some smart-home protocols need local discovery:

- mDNS
- IPv6 multicast
- Matter discovery
- Thread border routing

Do not blindly block all multicasts if you use Matter, Thread, HomeKit, or local discovery.
