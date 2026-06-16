# UniFi Firewall Notes

These are example firewall ideas for a segmented smart-home network.

Adjust them to your own VLANs and subnets.

## Recommended Placement

- Management access: management VLAN or admin subnet
- Service access: service / infrastructure VLAN
- Remote administration: VPN first

## Example Flows

```text
Trusted users   -> LISA Edge: selected dashboards and APIs
Controllers     -> LISA Edge: MQTT, DNS, NTP, OTBR services as needed
IoT devices     -> LISA Edge: only required ports
Cameras         -> LISA Edge: deny by default unless explicitly needed
Admin/VPN       -> LISA Edge: SSH and admin dashboards
Internet        -> LISA Edge dashboards: deny
```

## Notes

Matter, Thread, HomeKit, and local discovery may require IPv6 and multicast behavior to be handled carefully.
