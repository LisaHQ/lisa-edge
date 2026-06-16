# USB Autoinstall Flow

The USB autoinstall files are templates for unattended Ubuntu Server installation.

They are useful when you want to rebuild an edge host without manually connecting a keyboard and monitor.

## Important

The included `user-data` file is a template.

Before using it, change:

- hostname
- username
- SSH public key
- disk match rule
- Git repository URL if needed

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
tools/usb/autoinstall/user-data
tools/usb/autoinstall/meta-data
tools/usb/autoinstall/grub.cfg
```
