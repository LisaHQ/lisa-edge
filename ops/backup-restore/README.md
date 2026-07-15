# Backup and Restore

This directory owns the standard LISA Edge archive format, checksum helpers,
privileged validator and full-backup systemd units. Use the root facade:

```bash
sudo ./lisa-edge backup
sudo ./lisa-edge restore /path/to/lisa-edge-backup.tar.gz
sudo ./lisa-edge restore --target-root /mnt/lisa-production /path/to/backup.tar.gz
```

Format v3 archives use logical members (`.env`, `data/`, `docker/`, `state/`,
`secrets/`, `otbr/`) so they do not depend on the source checkout path. Backup
briefly stops the selected stack, creates the archive and checksum, then restarts
the stack. Configure `BACKUP_REQUIRE_MOUNT=1` for external destinations that
must fail closed when absent.

Restore verifies the adjacent `.sha256`, validates `.env` and every archive
member, extracts into protected staging, and skips deployment by default. It
also reads trusted legacy format-v2 archives. `--target-root` is restricted to
an exact mount below `/mnt` and can never deploy containers.

Archives contain credentials and service state and are not encrypted. Store
them on encrypted external media or in an encrypted backup repository.

The full-backup timer runs daily at 03:30. OTBR dataset scheduling belongs to
`services/otbr/systemd/`.

Operator runbook: [Backup and Restore](../../docs/operations/backup-restore.md).
