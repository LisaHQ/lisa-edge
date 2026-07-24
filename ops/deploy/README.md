# Deploy and Runtime Lifecycle

This directory owns deployment, stop/update, readiness, status and production
systemd integration. Operators should use the stable root facade:

```bash
sudo ./lisa-edge deploy              # pull only missing images
sudo ./lisa-edge deploy --pull       # refresh selected images
sudo ./lisa-edge deploy --offline    # never pull
sudo ./lisa-edge status              # non-invasive state snapshot
sudo ./lisa-edge health              # readiness checks
sudo ./lisa-edge stop
sudo ./lisa-edge update              # git fast-forward + refreshed images
sudo ./lisa-edge update clean        # discard local changes to tracked files,
                                     # reset to the remote branch, then refresh
```

Deployment reads `.env`, validates `DATA_ROOT`, selection keys and image policy,
builds the Compose stack from `compose.yml` plus each selected
`services/<owner>/compose.yml`, prepares MQTT when selected, starts containers,
performs OTBR dataset initialization/recovery when selected, and finishes with
the health check.

`systemd/lisa-edge.service` owns boot-time start/stop. `install-systemd.sh`
installs runtime, backup, first-boot and OTBR dataset units and creates the
`lisa-edge`/`lisa-edge-provision` command links.

`reset-node.sh` is destructive and intentionally not exposed as a casual CLI
command. It removes persistent runtime data only after an explicit `RESET`
confirmation.

Public behavior: [operations diagnostics](../../docs/operations/diagnostics.md).
Service selection: [`services/`](../../services/README.md).
