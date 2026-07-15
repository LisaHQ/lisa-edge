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

Persistent-data and backup roots must not overlap protected system trees such
as `/etc`, `/usr`, `/opt`, `/root` or `/tmp`. Prefer `/srv/lisa-edge`, `/data`,
or a dedicated mount below `/mnt` or `/media`.

Each archive has a `.sha256` checksum sidecar and, when `jq` is available, a
`.manifest.json` file describing its host, Git revision and selected services.

Restore requires the checksum sidecar by default. `--allow-missing-checksum`
exists only for recovery of a known, trusted legacy backup. A checksum detects
corruption but does not authenticate who created an archive.

The tar archive itself is not encrypted. Use encrypted storage or copy it into
an encrypted restic repository before it leaves the trusted host.

## Restore

```bash
sudo ./scripts/restore.sh /path/to/lisa-edge-backup.tar.gz
```

Restore validates the archived `.env`, rejects hard links and device nodes,
restricts members to the repository configuration and configured persistent
data roots, and extracts into a protected staging directory before copying any
file into the system. Only restore archives from a trusted host or storage
location. Clone LISA Edge at the same absolute repository path used by the
source host (normally `/opt/lisa-edge`) before restoring.

Restore does not start containers by default. It restores the validated `.env`
and persistent data, but keeps the checked-out Compose and static configuration
as the source of truth. Review `.env` and the selected image references, then
deploy explicitly:

```bash
sudo ./scripts/deploy.sh
# Or, for a fully trusted archive:
sudo ./scripts/restore.sh --deploy /path/to/lisa-edge-backup.tar.gz
```

Container image refresh is separate from normal deployment:

```bash
sudo ./scripts/deploy.sh          # pull only images that are missing
sudo ./scripts/deploy.sh --pull   # explicitly refresh selected images
sudo ./scripts/deploy.sh --offline
```

For reproducible production releases, replace the image references in `.env`
with release tags or multi-architecture manifest digests.

Test restore regularly on a spare host or isolated VM. A backup is not proven
until the restored services and OTBR dataset have been validated.

## Production Recommendation

Store backups outside the edge host:

- NAS
- external SSD
- encrypted restic repository
- offline archive
