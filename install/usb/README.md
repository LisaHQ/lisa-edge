# LISA Edge USB Installer

This folder contains everything needed to produce Ubuntu Server installation
media for LISA Edge — from downloading the ISO to a bootable, autoinstall-ready
USB. No third-party imaging tool (Rufus, Etcher, ...) is required.

It supports two installation profiles:

```text
install/usb/
├── README.md
├── config/
│   ├── ubuntu-releases.json        Ubuntu release/mirror definition
│   ├── production/                 Production autoinstall profile
│   │   ├── grub.cfg
│   │   ├── meta-data
│   │   └── user-data.template
│   └── rescue/                     Rescue autoinstall profile
│       ├── grub.cfg
│       ├── meta-data
│       └── user-data.template
│
└── scripts/
    ├── build/                      Full pipeline: fetch ISO → bootable USB → inject profile
    │   ├── build-ubuntu-usb.cmd    Windows orchestrator
    │   ├── build-ubuntu-usb.sh     Linux orchestrator
    │   └── platform/
    │       ├── linux/
    │       │   ├── create-usb-disk.sh
    │       │   └── fetch-ubuntu-iso.sh
    │       └── windows/
    │           ├── create-usb-disk.ps1
    │           └── fetch-ubuntu-iso.ps1
    │
    └── prepare/                    Inject-only: autoinstall files onto an existing USB
        ├── generate-user-data.ps1
        ├── prepare-production-usb.cmd
        ├── prepare-production-usb.sh
        ├── prepare-rescue-usb.cmd
        └── prepare-rescue-usb.sh
```

---

## Deployment Model

Recommended ZimaBoard 2 storage layout:

```text
eMMC
└── Rescue Layer (minimal Ubuntu Server, SSH, recovery tooling)

SSD
└── Production Layer (Ubuntu Server, Docker, LISA Edge services)
```

The **production** installer targets the SSD.
The **rescue** installer targets the onboard eMMC and must stay minimal.

---

## Build Pipeline (recommended)

The build pipeline replaces the old manual flow (Rufus + prepare script).
It runs three steps:

1. **fetch** — download the Ubuntu Server ISO defined in
   `config/ubuntu-releases.json` and verify its SHA256 checksum.
   ISOs are cached (`~/.cache/lisa-edge/iso` on Linux,
   `%LOCALAPPDATA%\lisa-edge\iso` on Windows) and reused when still valid.
2. **write** — erase the selected USB device and create a bootable installer:
   GPT + a single FAT32 partition + the full ISO contents.
   This is what Rufus "ISO mode" does, scripted and fail-closed.
3. **inject** — run the matching `scripts/prepare/` script to place the
   autoinstall profile (`user-data`, `meta-data`, `grub.cfg`) on the USB.

### Linux

```bash
# identify the USB device first (never guess):
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TYPE,TRAN,RM,MOUNTPOINTS

sudo ./lisa-edge usb build production --device /dev/sdX
sudo ./lisa-edge usb build rescue --device /dev/sdX
```

Useful options: `--dry-run`, `--yes`, `--iso <path>` (skip download),
`--release <series>`, `--keep-mounted`.

### Windows (elevated prompt)

```bat
lisa-edge usb build list
lisa-edge usb build production 2
lisa-edge usb build rescue 2 --dry-run
```

`2` is the disk number reported by `usb build list`. Only disks with
BusType `USB` are accepted; boot and system disks are always rejected.

### Boot support

The created USB boots **UEFI systems only** (ZimaBoard 2, NUC, and modern
mini PCs). Legacy BIOS boot is intentionally not supported: it would require
repacking the ISO and would make the USB read-only for autoinstall injection.

### Release pinning

`config/ubuntu-releases.json` selects the Ubuntu series and mirror. By
default the newest point release listed in the mirror's `SHA256SUMS` is used.
For fully reproducible media, pin both `iso` and `sha256` in that file.

---

## Inject-Only Flow (existing installer USB)

If you already have a bootable Ubuntu Server USB (made by the build pipeline
or any other tool), you can inject or refresh the autoinstall profile alone:

Linux:

```bash
sudo ./lisa-edge usb production --auto-detect
sudo ./lisa-edge usb production /media/$USER/UBUNTU_USB
sudo ./lisa-edge usb rescue /media/$USER/UBUNTU_USB
```

Windows:

```bat
lisa-edge usb production E:
lisa-edge usb rescue E:
```

---

## Important Safety Rules

Production installation may use `size: largest` only when you are certain the
SSD is the largest disk attached.

Rescue installation should never use `size: largest`. Always match the eMMC
explicitly by serial in `config/rescue/user-data.template`:

```yaml
match:
  serial: YOUR_EMMC_SERIAL
```

Identify disks on the target machine with:

```bash
sudo ./lisa-edge rescue disks
```

or:

```bash
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TYPE,TRAN,MOUNTPOINTS
```

The build pipeline never guesses the USB device: the device/disk number is a
mandatory argument, only removable USB-class devices are accepted, and
destructive steps require explicit confirmation (or `--yes`/`--dry-run`).

Never commit a generated `user-data`; only `user-data.template` is tracked.
