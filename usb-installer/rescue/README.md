# LISA Edge Rescue Layer

This folder contains scripts for building and maintaining the **Rescue Layer** on the ZimaBoard eMMC.

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
    ├── OTBR
    ├── MQTT
    ├── VPN
    └── LISA Edge runtime
```

The Rescue Layer should stay small, stable, and boring.

It should not run production services.

---

## Files

```text
rescue/
├── README.md
├── autoinstall/
│   ├── grub.cfg
│   ├── meta-data
│   └── user-data.template
└── scripts/
    ├── bootstrap-rescue.sh
    ├── detect-disks.sh
    ├── diagnostics.sh
    ├── mount-production.sh
    ├── restore-production.sh
    ├── reinstall-production.sh
    └── update-rescue-scripts.sh
```

---

## Installation Flow

### 1. Install minimal Ubuntu Server to eMMC

Use the autoinstall template:

```text
rescue/autoinstall/user-data.template
```

Before using it, replace:

```text
REPLACE_WITH_EMMC_SERIAL
```

with the real eMMC serial.

To inspect disks:

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,TRAN
```

or after copying this folder to a running Linux system:

```bash
sudo bash rescue/scripts/detect-disks.sh
```

### 2. Boot into the eMMC Rescue OS

Then run:

```bash
sudo bash rescue/scripts/bootstrap-rescue.sh
```

This installs rescue packages and places recovery scripts under:

```text
/opt/lisa-rescue
```

---

## Safety Notes

These scripts are intentionally conservative.

They do not automatically format production disks.

Destructive actions require explicit environment variables or arguments.

This is by design.

Recovery should be reliable, not clever.
