# USB Autoinstall Flow

The USB autoinstall files are templates for unattended Ubuntu Server installation.

They are useful when you want to rebuild an edge host without manually connecting a keyboard and monitor.

## Important

The repository includes `user-data.template`. A generated `user-data` is a
machine-specific local artifact and must not be committed.

Before using it, change:

- hostname
- username
- SSH public key
- disk match rule
- Git repository URL if needed

The production template locks password login and expects SSH-key access. After
installation, set a console password explicitly with `sudo passwd lisa` if one
is required. The installer grants the `lisa` administration account
passwordless sudo because the account itself has no usable password; protect
the corresponding SSH private key accordingly.

## Disk Safety

Autoinstall can wipe disks.

Use explicit disk matching by model or serial when possible.

Do not blindly use `/dev/sda` on systems with multiple drives.

## Flow

```text
Prepare Ubuntu USB
  ↓
Copy cloud-init files
  ↓
Boot target host
  ↓
Ubuntu installs automatically
  ↓
Repository is cloned
  ↓
Bootstrap script runs
  ↓
LISA Edge services start
```

## Files

```text
usb-installer/production/autoinstall/user-data.template
usb-installer/production/autoinstall/meta-data
usb-installer/production/autoinstall/grub.cfg
```
