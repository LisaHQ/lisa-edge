# Quick Start

LISA Edge has one stable operator interface:

```bash
./lisa-edge help
```

Choose one installation path. Do not combine the steps from different paths.

| Starting point | Use |
| --- | --- |
| Ubuntu or Debian is already installed | Manual fresh setup below |
| You need an unattended Ubuntu install | [USB Autoinstall Flow](03-autoinstall-flow.md) |
| You are rebuilding from a backup | [First-Boot Provisioning](06-first-boot-provisioning.md) |

## Manual fresh setup

Automated host bootstrap currently supports Ubuntu Server and Debian.

### 1. Clone the repository

```bash
sudo git clone https://github.com/LisaHQ/lisa-edge.git /opt/lisa-edge
cd /opt/lisa-edge
```

For production, check out a reviewed release tag or commit rather than an
unreviewed development branch.

### 2. Run setup

```bash
sudo ./lisa-edge setup
```

Choose **Fresh deployment**, review storage and backup paths, select services,
and complete each selected service's wizard. When prompted, allow setup to run
bootstrap and deploy.

Setup performs the full path:

```text
configuration → host bootstrap → service deployment → systemd install → health
```

### 3. Verify

```bash
sudo ./lisa-edge status
sudo ./lisa-edge health
```

Then complete the [Deployment Validation](05-deployment-validation.md).

## Configure now, bootstrap later

To write or update `.env` without changing the host or starting services:

```bash
sudo ./lisa-edge configure
```

Review the result, then apply it later:

```bash
sudo ./lisa-edge bootstrap
```

Do not hand-copy `.env.template` for a normal installation. The wizard validates
paths, service dependencies, ports, image policy, backup mounts, and admin
access that a manual copy would bypass.

## Add or remove services later

```bash
sudo ./lisa-edge setup
```

Re-running setup preserves existing values as defaults and backs up the current
`.env` before replacing it. Persistent service data is not deleted when a
service is deselected.

## Next steps

- [Choose services](02-service-selection.md)
- [Review the deployment checklist](04-deployment-checklist.md)
- [Understand first-boot and restore modes](06-first-boot-provisioning.md)
