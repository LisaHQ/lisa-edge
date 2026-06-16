# Deployment Validation

This checklist helps confirm that a LISA Edge deployment is ready for normal operation.

Use it after a fresh install, restore, major configuration change, or hardware replacement.

---

## Host Validation

- [ ] Host boots without keyboard, monitor, or manual BIOS interaction
- [ ] Correct OS is installed
- [ ] Hostname is correct
- [ ] Time synchronization works
- [ ] SSH key authentication works
- [ ] Password login is disabled if required
- [ ] Required packages are installed
- [ ] Docker is installed
- [ ] Docker Compose works
- [ ] Host survives reboot cleanly

---

## Storage Validation

- [ ] OS is on intended boot storage
- [ ] Docker data is not writing heavily to eMMC
- [ ] SSD or external storage is mounted correctly
- [ ] Mounts survive reboot
- [ ] Backup destination is reachable
- [ ] Logs are not growing uncontrollably

---

## Network Validation

- [ ] Correct VLAN or subnet is used
- [ ] Static IP or DHCP reservation is configured
- [ ] DNS resolution works
- [ ] Local service discovery works as expected
- [ ] Firewall rules allow only required traffic
- [ ] Sensitive networks remain isolated
- [ ] VPN access works
- [ ] Admin dashboards are not publicly exposed

---

## Service Validation

- [ ] Docker services start successfully
- [ ] Health checks pass
- [ ] MQTT is reachable by intended clients
- [ ] OTBR is healthy if enabled
- [ ] NUT detects UPS if enabled
- [ ] reverse proxy routes only intended services
- [ ] monitoring detects service failure
- [ ] restart policies work after reboot

---

## Thread / Matter Validation

If OTBR or Matter-over-Thread is enabled:

- [ ] Thread adapter is detected
- [ ] OTBR service starts cleanly
- [ ] Thread network is visible
- [ ] Thread Dataset backup exists
- [ ] Dataset restore procedure is documented
- [ ] adapter replacement procedure is documented
- [ ] Matter devices remain functional after service restart

---

## Backup Validation

- [ ] Backup job runs successfully
- [ ] Backup includes Compose files
- [ ] Backup includes `.env` or documented secret restoration path
- [ ] Backup includes persistent service data
- [ ] Backup includes Thread Dataset if applicable
- [ ] Backup destination is outside the LISA Edge host
- [ ] Restore has been tested at least once

---

## Recovery Validation

- [ ] Host reinstall procedure is documented
- [ ] Docker redeploy procedure is documented
- [ ] Service restore procedure is documented
- [ ] OTBR restore procedure is documented if applicable
- [ ] Recovery does not depend on undocumented manual steps

---

## Production Readiness Decision

A deployment should not be considered production-ready until:

- backups exist
- restore has been tested
- VPN access works
- firewall boundaries are preserved
- monitoring is active
- critical services restart after reboot
