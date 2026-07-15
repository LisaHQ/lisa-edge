# Backup and Restore

The public interface is the root command; implementation is owned by
[`ops/backup-restore/`](../../ops/backup-restore/README.md).

## Create a backup

```bash
sudo ./lisa-edge backup
sudo ./lisa-edge health
```

Backup briefly stops the selected Compose stack for a consistent snapshot,
creates the archive, then starts the stack again. Format v3 archives use a
portable logical layout containing `.env`, persistent `data/`, `docker/`,
`state/`, `secrets/` and an OTBR dataset copy when present. Checked-out code and
static service definitions remain sourced from Git.

The default destination is `${DATA_ROOT}/backups`, retention is 14 days, and
each archive receives a required `.sha256` sidecar. When `jq` is available, a
`.manifest.json` records format, host, Git revision and selected services.

For NAS or removable storage, configure:

```env
BACKUP_DEST=/mnt/backup/lisa-edge
BACKUP_REQUIRE_MOUNT=1
BACKUP_EXPECTED_MOUNT_SOURCE=nas:/volume/lisa-edge
```

The mount guard fails closed rather than writing to the root filesystem. Keep
backups outside the edge host. Archives contain credentials and service state
and are not encrypted; use encrypted storage or an encrypted backup repository.

## Restore to the live host

```bash
sudo ./lisa-edge restore /path/to/lisa-edge-backup.tar.gz
# Review .env and image references, then:
sudo ./lisa-edge deploy
```

Restore requires the adjacent checksum by default, validates `.env`, rejects
unsafe archive members, extracts into protected staging and does not deploy
unless `--deploy` is explicitly supplied. Format v3 is path-independent; the
restore command also accepts trusted legacy format-v2 archives.

`--allow-missing-checksum` is only for a known trusted legacy archive. A
checksum detects corruption but does not authenticate the archive producer.

## Restore into a mounted replacement filesystem

From the Rescue OS, mount the production root below `/mnt`, then use:

```bash
sudo ./lisa-edge restore --target-root /mnt/lisa-production /path/to/backup.tar.gz
```

The target must be an exact mounted filesystem. Target-root restore never
deploys containers. The higher-level rescue entrypoint is
`sudo ./lisa-edge rescue restore-backup ...`.

## Scheduled backups

`lisa-edge-backup.timer` runs daily at 03:30 with a randomized delay. Inspect or
trigger it with:

```bash
systemctl list-timers 'lisa-*'
sudo systemctl start lisa-edge-backup.service
journalctl -u lisa-edge-backup.service -n 100 --no-pager
```

Test restore on representative spare hardware. A backup is not proven until
the restored services, credentials and OTBR dataset have been verified.
