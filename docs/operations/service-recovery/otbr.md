# OTBR Dataset Recovery

Use this runbook when the OTBR host or container is lost but the Thread Active
Operational Dataset is available. A full LISA Edge backup is preferred; this is
the dataset-only path.

Required state:

```text
latest.dataset.hex
```

Treat this file as a secret. It contains the identity and credentials of the
Thread network.

## Fresh-host procedure

1. Install Linux and clone LISA Edge.
2. Configure without deploying; select OTBR and the correct RCP/backbone:

   ```bash
   sudo ./lisa-edge configure
   ```

3. Point the wizard at the saved dataset. The OTBR wizard's "Thread dataset
   detection" step accepts a custom path (for example a mounted USB or NAS
   directory), lists the `*.hex` backups it finds, and stages the selected file
   for restore on the next deploy. Alternatively, copy the saved dataset to the
   `OTBR_DATASET_LATEST` path in `.env` manually. For the default layout:

   ```bash
   sudo install -D -m 0600 /path/to/latest.dataset.hex \
     /srv/lisa-edge/backups/otbr/latest.dataset.hex
   ```

4. Bootstrap and deploy. OTBR detects the empty runtime state and restores the
   saved dataset automatically:

   ```bash
   sudo ./lisa-edge bootstrap
   ```

5. Verify attachment and dataset identity:

   ```bash
   sudo ./lisa-edge health
   docker exec lisa-otbr ot-ctl state
   docker exec lisa-otbr ot-ctl dataset active -x
   ```

An attached network normally reports `child`, `router` or `leader`. Confirm
Thread devices reconnect and Matter automations work before declaring recovery
complete.

Keep `OTBR_AUTO_RESTORE_DATASET=1` and `OTBR_AUTO_CREATE_NETWORK=0` in
production. Without a dataset backup, a new Thread network must be created and
devices may need factory reset or re-pairing.

## Agent not ready: "connect session failed"

`ot-ctl` reports `connect session failed: No such file or directory` when the
`lisa-otbr` container is running but otbr-agent inside it has not started, so
the agent control socket does not exist. Deploy fails closed in this state
instead of making dataset decisions.

Inspect next:

```bash
docker logs --tail 50 lisa-otbr
ls -l /dev/serial/by-id/
```

Common causes: `THREAD_RADIO_DEVICE` does not point at the attached RCP radio,
the radio re-enumerated under a new path after replugging, `THREAD_RADIO_URL`
uses the wrong UART baud rate, or `OTBR_BACKBONE_IF` does not match an active
host interface. Fix `.env` (or rerun `sudo ./lisa-edge configure`) and deploy
again.

Implementation ownership: [`services/otbr/`](../../../services/otbr/README.md).
