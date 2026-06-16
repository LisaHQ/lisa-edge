# LISA Edge USB Installer

This folder contains Ubuntu autoinstall assets for LISA Edge.

It supports two installation profiles:

```text
usb-installer/
├── production/
│   └── autoinstall/
│       ├── grub.cfg
│       ├── meta-data
│       └── user-data
│
└── rescue/
    └── autoinstall/
        ├── grub.cfg
        ├── meta-data
        └── user-data
```

---

## Deployment Model

Recommended ZimaBoard 2 storage layout:

```text
eMMC
└── Rescue Layer
    ├── minimal Ubuntu Server
    ├── SSH
    ├── network tools
    ├── diagnostics
    └── recovery scripts

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

---

## Production Installer

Purpose:

Install the daily-use LISA Edge production OS onto the SSD.

Expected target:

```text
SSD
```

Production installer files:

```text
usb-installer/production/autoinstall/
```

---

## Rescue Installer

Purpose:

Install the lightweight Rescue OS onto the onboard eMMC.

Expected target:

```text
eMMC
```

Rescue installer files:

```text
usb-installer/rescue/autoinstall/
```

The Rescue OS should stay minimal.

Do not run production Docker services on the Rescue OS.

---

## Important Safety Rule

Production installation may use `size: largest` only when you are certain the SSD is the largest disk attached.

Rescue installation should never use `size: largest`.

For Rescue OS installation, always match the eMMC explicitly by serial:

```yaml
match:
  serial: YOUR_EMMC_SERIAL
```

Use:

```bash
tools/detect-disks.sh
```

or:

```bash
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TYPE,TRAN,MOUNTPOINTS
```

to identify the correct disk.

---

## Linux Usage

Prepare rescue USB files:

```bash
cd lisa-edge
sudo bash usb-installer/rescue/prepare-ubuntu-rescue-usb.sh /media/$USER/UBUNTU_USB
```

---

## Windows Usage

Prepare rescue USB files:

```bat
usb-installer\rescue\prepare-ubuntu-rescue-usb.bat E:
```

Replace `E:` with your USB drive letter.

---

## Notes

These scripts do not download Ubuntu ISO.

Recommended flow:

1. Create Ubuntu Server USB using Rufus, Balena Etcher, Ventoy, or another ISO tool.
2. Mount the USB.
3. Run the matching prepare script.
4. Boot the target machine from USB.
5. Confirm the installer targets the correct disk.
