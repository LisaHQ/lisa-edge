# Tools

This directory contains developer, build, and validation utilities. Commands
required during normal service operation belong in `scripts/`.

- `validate-repo.sh` is the repository-wide CI entrypoint.
- `validate-compose.sh` renders and validates selected Compose fragments.
- `build-usb.sh` prepares production or rescue USB build assets.
- `generate-secrets.sh` generates values for external secure storage.
- `detect-disks.sh` reports candidate storage devices without modifying them.
- `disaster-recovery-check.sh` checks recovery prerequisites.

Run the same validation used by CI with:

```bash
bash tools/validate-repo.sh
```

Most tools target Linux. USB-specific Windows helpers remain next to their
profiles under `usb-installer/`.
