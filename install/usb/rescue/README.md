# LISA Edge Rescue USB Installer

This directory contains the Ubuntu autoinstall profile for the **Rescue
Layer** on the ZimaBoard eMMC. Runtime rescue commands live at repository root
under `rescue/` and are exposed through the root `lisa-edge` command.

Recommended architecture:

```text
eMMC
└── Rescue Layer
    ├── minimal Ubuntu Server
    ├── SSH
    ├── network tools
    ├── disk diagnostics
    ├── backup / restore helpers
    └── production recovery scripts

SSD
└── Production Layer
    ├── Ubuntu Server
    ├── Docker
    ├── Compose services
    └── LISA Edge runtime
```

The Rescue Layer should stay small, stable, and should not run production
services.

## Repository paths

```text
install/usb/rescue/
├── README.md
├── autoinstall/
│   ├── grub.cfg
│   ├── meta-data
│   └── user-data.template
├── prepare-ubuntu-rescue-usb.sh
└── prepare-ubuntu-rescue-usb.bat

rescue/
├── scripts/
└── systemd/
```

## Installation flow

### 1. Prepare the autoinstall profile

Review:

```text
install/usb/rescue/autoinstall/user-data.template
```

Replace the eMMC serial, SSH public key, and password-hash placeholders. Find
the correct disk with:

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,TRAN
```

Prepare an existing Ubuntu Server installer USB:

```bash
sudo bash install/usb/rescue/prepare-ubuntu-rescue-usb.sh /media/$USER/UBUNTU_USB
```

### 2. Bootstrap the installed Rescue OS

The autoinstall template clones the repository to `/opt/lisa-edge` and invokes:

```bash
sudo /opt/lisa-edge/lisa-edge rescue bootstrap
```

Other rescue tasks are available through `lisa-edge rescue`, for example:

```bash
sudo ./lisa-edge rescue disks
```

## Safety notes

Rescue commands are intentionally conservative. Destructive actions require
explicit arguments or confirmations. Always verify the target disk before an
install or reinstall.
