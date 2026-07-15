# LISA Edge Rescue OS

`rescue/` is the canonical implementation of the independent LISA Edge
Rescue OS installed on eMMC. It is deliberately separate from the production
Docker host on SSD.

The rescue environment exists to:

- inspect disks and networking when production will not boot;
- collect diagnostics without starting production services;
- mount the production root filesystem safely below `/mnt`;
- restore a verified LISA Edge backup archive into a mounted production root;
- restore a trusted filesystem snapshot when no LISA Edge archive is
  available; and
- guide a human through reinstalling the production OS.

It must stay small, stable, and non-destructive by default. Do not run the
production Compose stack on the Rescue OS.

## Layout

```text
rescue/
├── README.md
├── scripts/
│   ├── bootstrap.sh
│   ├── detect-disks.sh
│   ├── diagnostics.sh
│   ├── install-diagnostics-timer.sh
│   ├── mount-production.sh
│   ├── recovery-safety.sh
│   ├── reinstall-guide.sh
│   ├── restore-edge-backup.sh
│   ├── restore-filesystem-snapshot.sh
│   └── update-rescue-scripts.sh
└── systemd/
    ├── lisa-rescue-diagnostics.service
    └── lisa-rescue-diagnostics.timer
```


## Install or refresh the Rescue OS tools

From a LISA Edge checkout on the Rescue OS:

```bash
sudo bash rescue/scripts/bootstrap.sh
```

This installs the scripts and systemd assets below `/opt/lisa-rescue`. To
refresh an existing Rescue OS from Git later:

```bash
sudo /opt/lisa-rescue/scripts/update-rescue-scripts.sh
```

The updater only replaces Rescue OS tooling. It does not touch production
storage or start production services.

## Typical recovery workflow

1. Collect diagnostics:

   ```bash
   sudo /opt/lisa-rescue/scripts/diagnostics.sh
   ```

2. Identify the production partition:

   ```bash
   sudo /opt/lisa-rescue/scripts/detect-disks.sh
   ```

3. Mount it at the dedicated rescue mountpoint:

   ```bash
   sudo /opt/lisa-rescue/scripts/mount-production.sh /dev/sdX2
   ```

4. Choose exactly one restore workflow.

### Restore a LISA Edge backup archive

Use this for archives created by the LISA Edge backup command. A matching
checksum sidecar is required by the main restore implementation.

```bash
sudo /opt/lisa-rescue/scripts/restore-edge-backup.sh \
  /mnt/lisa-backup/lisa-edge-backup-YYYYMMDD-HHMMSS.tar.gz \
  /mnt/lisa-production
```

The wrapper verifies that the target is an exact mount below `/mnt`, then calls
the repository's stable interface:

```text
lisa-edge restore --target-root <mounted-root> <archive>
```

Target-root restore never deploys containers.

### Restore a filesystem snapshot

Use this only for a trusted directory snapshot intended to be copied over the
entire mounted production filesystem. This is not the LISA Edge `.tar.gz`
backup format.

```bash
export SNAPSHOT_SOURCE=/mnt/lisa-backup/filesystem-snapshot
export PRODUCTION_ROOT=/mnt/lisa-production
sudo -E /opt/lisa-rescue/scripts/restore-filesystem-snapshot.sh
```

The legacy `BACKUP_SOURCE` variable remains accepted for compatibility.

### Reinstall production

`reinstall-guide.sh` is intentionally non-destructive. It prints disk details
and the human-reviewed reinstall sequence; it never partitions or formats a
disk.

```bash
sudo /opt/lisa-rescue/scripts/reinstall-guide.sh
```

## Safety guarantees

- Restore targets must resolve below `/mnt` and cannot be `/mnt` itself.
- Restore targets must be dedicated mountpoints verified with `findmnt`.
- Backup or snapshot sources cannot overlap the production root.
- Destructive restore operations require explicit confirmation.
- Production reinstall remains a guide, not an automated disk-writing script.
- Rescue diagnostics may inspect production hardware but do not mount or write
  disks automatically.

