# OpenThread Border Router

OTBR connects a Thread mesh to the IP network for Matter-over-Thread. It is an
optional service with selection key `otbr`; the canonical owner is
[`services/otbr/`](../../services/otbr/README.md).

## Requirements

- A Thread radio running RCP firmware
- A stable `/dev/serial/by-id/...` device path
- IPv6 and `/dev/net/tun` on the host
- The correct service-facing backbone interface

Use `sudo ./lisa-edge setup` to select OTBR and configure
`THREAD_RADIO_DEVICE`, `OTBR_BACKBONE_IF`, dataset storage and restore policy.
The wizard lists serial radios detected under `/dev/serial/by-id/` and active
host interfaces (defaulting to the default-route interface) as selectable
choices. When `OTBR_IMAGE` is left on a floating tag, the wizard also resolves
the newest `openthread/border-router` release tag (`vYYYY.MM.N`) from Docker
Hub as the default image; if the host is offline it keeps the configured
reference. Host bootstrap prepares Avahi and IPv6 forwarding when OTBR is
selected.

Deploy and verify:

```bash
sudo ./lisa-edge deploy
sudo ./lisa-edge health
docker exec lisa-otbr ot-ctl state
docker exec lisa-otbr ot-ctl dataset active -x
```

An attached network normally reports `child`, `router` or `leader`.

## Thread dataset safety

The Active Operational Dataset contains the Thread network key, PSKc, channel,
PAN identifiers and mesh prefix. Treat it as a secret. Losing it can require
factory-resetting or re-pairing Thread devices.

Recommended production policy:

```env
OTBR_AUTO_RESTORE_DATASET=1
OTBR_AUTO_CREATE_NETWORK=0
```

Deploy automatically backs up an existing active dataset or restores
`OTBR_DATASET_LATEST` when the container has no dataset. It refuses to create a
new network unless explicitly allowed. Dataset snapshots live under
`OTBR_DATASET_BACKUP_DIR`, defaulting to
`/srv/lisa-edge/backups/otbr/`; the dataset timer is enabled automatically when
OTBR is selected.

Keep an encrypted copy outside the edge host. See the
[OTBR recovery runbook](../operations/service-recovery/otbr.md) before hardware
migration or disaster recovery.

Related background: [Thread](../networking/thread.md) and
[Matter](../networking/matter.md).
