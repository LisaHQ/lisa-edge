# First-Boot Provisioning Wizard

The provisioning wizard is the preferred way to create or update `.env` after
an autoinstall. It can also be run on a manually installed host:

```bash
sudo lisa-edge-provision
```

From a repository checkout, use:

```bash
sudo ./provisioning/lisa-first-boot.sh
```

## Provisioning modes

- **Fresh deployment** creates a new configuration and deploys it.
- **Restore from USB** discovers archives on a volume labeled `LISA_BACKUP` or
  under common removable-media mount paths.
- **Restore from path** accepts a backup archive or a mounted NAS directory.
- **Configure only** writes `.env` without installing or starting services.

Restore is never started merely because an archive exists. The operator must
select the archive, a matching `.sha256` sidecar is required and verified, and
restored values become defaults that can be reviewed before deployment. The
archive is also restricted to LISA Edge configuration and persistent-data
paths before any privileged restore is performed.

The global wizard also asks whether backups must stay on a mounted filesystem,
whether selected container images must use immutable digests, and whether the
temporary autoinstall passwordless-sudo grant may remain. Production defaults
remove passwordless sudo after bootstrap.

## Service selection

The wizard accepts service numbers, service names, multiple values separated
by commas/spaces, or `all`.

| ID | Service | Configuration wizard |
|---|---|---|
| `mqtt` | Eclipse Mosquitto | username, password, bind IP and ports |
| `uptime-kuma` | Uptime Kuma | bind IP and port |
| `otbr` | OpenThread Border Router | RCP device, interfaces and dataset policy |
| `vpn-tailscale` | Tailscale | auth key and additional arguments |
| `ha` | Home Assistant | host-networking notice and data placement |
| `zigbee2mqtt` | Zigbee2MQTT | coordinator device, bind IP and port |
| `node-red` | Node-RED | bind IP and port |

Selecting Zigbee2MQTT automatically selects MQTT. Deployment validation also
rejects a hand-written configuration that violates this dependency.

## NAS restore

Mount the NAS before running the wizard, then select **Restore from a mounted
NAS/local path** and provide either the directory or archive path. For example:

```bash
sudo mount -t nfs nas.example:/volume/lisa-edge /mnt/lisa-backup
sudo lisa-edge-provision --mode restore-path --backup /mnt/lisa-backup
```

NAS credentials are not stored in USB autoinstall `user-data` by the wizard.
When this path will also receive scheduled backups, enable the mount requirement
and record the expected mount source offered by the wizard.

## Image and admin-access review

Before writing `.env`, the wizard lists each selected service and its image
reference as `floating` or `pinned`. Restored references require a separate
operator confirmation. Enabling immutable-image enforcement rejects every
selected image that does not end in an `@sha256` digest.

Autoinstall uses `/etc/sudoers.d/90-lisa-admin` only as a bootstrap grant. At
the end of bootstrap, LISA verifies that the configured admin account has a usable local
password (prompting interactively if needed) and then removes that grant. Set
`LISA_KEEP_PASSWORDLESS_SUDO=1` only as a deliberate lab/emergency exception.

## Re-running

The wizard backs up an existing `.env` before replacing it. It can be run again
to add or remove services. `docker compose --remove-orphans` removes containers
that are no longer selected without deleting their persistent bind-mounted
data.
