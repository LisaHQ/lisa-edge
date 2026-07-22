# OpenThread Border Router

- Selection key: `otbr`
- Enabled by default: no
- Container: `lisa-otbr`
- Requires: Thread RCP, stable serial path, IPv6 and `/dev/net/tun`

Run `sudo ./lisa-edge setup` to select the radio, backbone interface and dataset
policy. Then deploy and verify:

```bash
sudo ./lisa-edge deploy
sudo ./lisa-edge health
docker exec lisa-otbr ot-ctl state
```

The Thread dataset is a secret and the identity of the network. Dataset tools
under `dataset/` back it up, restore it or initialize OTBR. The wizard detects
existing dataset backups (default directory or a custom path), and can stage a
selected backup or a new-network request as a one-shot pending marker that the
next deploy applies; a running dataset is backed up first, optionally with a
filename description. Production should keep `OTBR_AUTO_RESTORE_DATASET=1` and
`OTBR_AUTO_CREATE_NETWORK=0`. The units in `systemd/` schedule dataset backups
when OTBR is selected.

Owned files: `compose.yml`, `provision.sh`, `dataset/` and `systemd/`. See the
[service reference](../../docs/services/otbr.md) and
[recovery runbook](../../docs/operations/service-recovery/otbr.md).
