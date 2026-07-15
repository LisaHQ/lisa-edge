# First-Boot Provisioning

Production autoinstall creates this convenience command:

```bash
sudo lisa-edge-provision
```

With no arguments, the alias dispatches to the canonical setup workflow:

```bash
sudo /opt/lisa-edge/lisa-edge setup
```

From any repository checkout, use the root `lisa-edge` command directly for
mode-specific options.

## Provisioning modes

| Mode | Purpose |
| --- | --- |
| Fresh | Create configuration, then bootstrap and deploy after confirmation |
| Restore from USB | Discover a backup on `LISA_BACKUP` or common removable-media paths |
| Restore from path | Use a selected archive or mounted NAS/local directory |
| Configure only | Write `.env` without changing the host or starting services |

Interactive selection:

```bash
sudo ./lisa-edge setup
```

Explicit fresh mode:

```bash
sudo ./lisa-edge setup --mode fresh
```

Configuration only:

```bash
sudo ./lisa-edge configure
sudo ./lisa-edge bootstrap
```

## Restore from USB

Attach the backup volume, then run:

```bash
sudo ./lisa-edge setup --mode restore-usb
```

The wizard can mount a volume labeled `LISA_BACKUP` read-only or discover
archives beneath common removable-media mount locations. An archive is never
restored merely because it exists; the operator must select it.

## Restore from NAS or local path

Mount network storage first:

```bash
sudo mount -t nfs nas.example:/volume/lisa-edge /mnt/lisa-backup
sudo ./lisa-edge setup \
  --mode restore-path \
  --backup /mnt/lisa-backup
```

The backup path may be a directory or a specific archive.

## Restore safety

Before privileged extraction, provisioning:

1. requires and verifies the matching `.sha256` sidecar;
2. validates archive member types and paths;
3. restricts extraction to LISA Edge configuration and persistent-data roots;
4. restores without deploying;
5. reloads restored values as editable wizard defaults; and
6. requires review of restored container image references.

After review, setup writes a fresh `.env` and offers to bootstrap and deploy.

## What the wizard asks

Global settings include:

- hostname and timezone;
- `DATA_ROOT` and `BACKUP_DEST`;
- backup mount enforcement and retention;
- selected service list;
- bind addresses and ports;
- immutable-image policy;
- administrator account; and
- whether temporary passwordless sudo may remain.

Each selected service then runs its own configuration prompts. Zigbee2MQTT
automatically adds MQTT.

Review current keys with:

```bash
./lisa-edge service list
```

## Images and administrator access

The wizard labels selected images as floating or digest-pinned. Enabling
immutable-image enforcement rejects any selected image without an `@sha256`
digest.

Autoinstall creates `/etc/sudoers.d/90-lisa-admin` only to make unattended
first bootstrap possible. Bootstrap confirms that the configured administrator
has a usable local password and removes the temporary grant unless the operator
explicitly keeps the emergency/lab override.

## Re-running setup

```bash
sudo ./lisa-edge setup
```

Existing values become defaults. The current `.env` is backed up before
replacement. Deselected containers are removed as orphans, but their
bind-mounted persistent data is retained for deliberate cleanup or later reuse.
