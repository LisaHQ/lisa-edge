# Systemd Units

This directory contains production runtime and backup units installed by
`scripts/install-systemd.sh`.

- `lisa-edge.service` manages the selected Compose stack.
- `lisa-edge-backup.*` schedules full backups.
- `lisa-otbr-dataset-backup.*` schedules Thread dataset backups when OTBR is
  enabled.

First-boot notification units stay under `provisioning/systemd/`, and rescue-only
units stay under `recovery/systemd/`, because they belong to different host
lifecycles.

Do not copy these files manually when the repository is installed outside
`/opt/lisa-edge`; the installer rewrites repository paths before installing the
units.
