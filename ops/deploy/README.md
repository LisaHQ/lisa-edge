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

## Reset lifecycle

`reset-node.sh` is the single canonical reset implementation behind
`lisa-edge reset`. It has three clearly separated modes, each guarded by a
complete plan printout and an exact confirmation phrase; `--dry-run` prints
the same plan without changing anything.

```bash
sudo ./lisa-edge reset data --dry-run
sudo ./lisa-edge reset data              # confirm with: RESET DATA
sudo ./lisa-edge reset provisioning --dry-run
sudo ./lisa-edge reset provisioning      # confirm with: RESET LISA
sudo ./lisa-edge reset factory --dry-run
sudo ./lisa-edge reset factory           # confirm with: RESET UBUNTU
```

| Goal         | Command                        | Keeps `.env` | Keeps local backups | Redeploys |   Reinstalls Ubuntu |
| ------------ | ------------------------------ | -----------: | ------------------: | --------: | ------------------: |
| Clean data   | `lisa-edge reset data`         |          Yes |                 Yes |       Yes |                  No |
| Clean LISA   | `lisa-edge reset provisioning` |           No |                  No |        No |                  No |
| Clean Ubuntu | `lisa-edge reset factory`      |           No |                  No |        No | Yes, through Rescue |

`reset data` stops the runtime unit and every production backup timer,
removes the Compose project's containers, networks and volumes
(project-scoped by Docker label; never a global prune), deletes the
LISA-owned runtime state under `DATA_ROOT` (`data`, `docker`, `state`,
`logs`, `secrets` — the Matter fabric, live OTBR state, MQTT data and its
generated password file, Tailscale/Zigbee2MQTT/Node-RED/Uptime Kuma state),
recreates the directory layout, redeploys with the retained `.env`, runs the
normal health check, and only then restarts the backup timers appropriate to
the selected services. If the redeploy fails, the timers stay stopped and
the exact recovery commands are printed. **It does not erase configuration
secrets stored in `.env`** (that is the point of this mode), and local
backups under `DATA_ROOT/backups` plus any external `BACKUP_DEST` survive.

`reset provisioning` returns the host to the unprovisioned first-boot state
without reinstalling Ubuntu: it removes all LISA runtime data and local
backups inside `DATA_ROOT`, the generated secrets, `.env` (plus `.env.tmp`
and `.env.before-wizard-*`), the provision marker and the installed
production units/timers, then reinstalls and enables
`lisa-first-boot.service` and the `lisa-edge-provision` link so the operator
can run `sudo lisa-edge-provision` again. **Docker Engine, images, build
cache, Ubuntu packages, SSH access and host bootstrap configuration (SSH
hardening, Thread sysctl, journald limits, Chrony, Avahi) are retained** —
this mode never attempts a package-by-package rollback. Backups outside
`DATA_ROOT` are preserved.

`reset factory` is the only mode that produces a clean Production Ubuntu
installation, and it never wipes a disk itself. From the running Production
OS it refuses (a system cannot safely erase the root filesystem it runs
from) and prints the steps to boot the independent Rescue Layer. From the
Rescue Layer it is a guarded handoff to the canonical production reinstall
procedure (`rescue reinstall`): the wipe happens exclusively through the
reviewed production autoinstall USB, which matches the target disk by
serial. The reinstalled Production OS boots unprovisioned. Automated
in-place reinstallation is intentionally not implemented.

All modes fail closed on unsafe `DATA_ROOT` values, traversal or symlinked
paths, mounted filesystems below a deletion target, and unreadable mount
tables. Rescue Layer units are never touched by `data` or `provisioning`.

Note: `lisa-edge matter reset` only wipes the Matter fabric data and is not
equivalent to any node reset mode.

Public behavior: [operations diagnostics](../../docs/operations/diagnostics.md).
Service selection: [`services/`](../../services/README.md).
