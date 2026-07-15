# Runtime Scripts

This directory contains commands used by operators and systemd after LISA Edge
has been installed. Build and repository-maintenance commands belong in
`tools/` instead.

Primary entrypoints:

- `deploy.sh` starts or refreshes the selected Compose services.
- `stop.sh` stops the selected services.
- `update.sh` fast-forwards the repository and deploys refreshed images.
- `healthcheck.sh` verifies configured services.
- `backup.sh` and `restore.sh` manage production backups.
- `collect-diag.sh` creates a diagnostics bundle.
- `reset-node.sh` removes local runtime state after safety checks.
- `install-systemd.sh` installs the production units.

Reusable shell functions and the privileged backup validator live in `lib/`.
Scripts should resolve the repository from their own path and must not assume
that the current working directory is the repository root.
