# UniFi Firewall Notes

Recommended placement:

- Management interface: VLAN_MGMT 99
- Service interface: VLAN_SVC 90

Allow only required flows:
```text
VLAN_MAIN 10  → VLAN_SVC 90: allowed only required dashboards/API
VLAN_CTRL 30  → VLAN_SVC 90: MQTT/OTBR/NTP/DNS/API as needed
VLAN_HUB 40   → VLAN_SVC 90: only required local integrations
VLAN_CAM_U 60 → VLAN_SVC 90: deny by default
VLAN_MGMT 99  → Reference deployment: SSH/admin allowed
VPN           → VLAN_MGMT 99 / VLAN_SVC 90 admin ports only
Internet      → Reference deployment dashboards: deny
```
