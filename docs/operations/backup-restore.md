# Backup and Restore

LISA Edge is designed to be rebuildable.

Back up:

- `.env`
- Docker volumes
- service configuration
- secrets
- OTBR Thread dataset if OTBR is used
- VPN state if Tailscale is used

## Backup

```bash
sudo ./scripts/backup.sh
```

The archive is created with mode `0600`, includes local secrets and the OTBR
dataset, and retains 14 days by default. Configure `BACKUP_DEST` on external or
network storage and adjust `BACKUP_RETENTION_DAYS` as needed.

Each archive has a `.sha256` checksum sidecar and, when `jq` is available, a
`.manifest.json` file describing its host, Git revision and selected services.

The tar archive itself is not encrypted. Use encrypted storage or copy it into
an encrypted restic repository before it leaves the trusted host.

## Restore

```bash
sudo ./scripts/restore.sh /path/to/lisa-edge-backup.tar.gz
```

Test restore regularly on a spare host or isolated VM. A backup is not proven
until the restored services and OTBR dataset have been validated.

## Production Recommendation

Store backups outside the edge host:

- NAS
- external SSD
- encrypted restic repository
- offline archive
