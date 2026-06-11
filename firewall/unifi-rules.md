# UniFi Firewall Notes

Recommended placement:

- Management interface: VLAN_MGMT 99
- Service interface: VLAN_SVC 90

Allow only required flows:

- VLAN_CTRL 30 -> VLAN_SVC 90: MQTT, OTBR REST/API if needed
- VLAN_MAIN 10 -> VLAN_SVC 90: dashboards by allowlist only
- VLAN_MGMT 99 -> ZimaBoard: SSH/admin
- Internet -> ZimaBoard: deny
