# USB Autoinstall Flow

LISA Edge has two Ubuntu Server installer profiles:

| Profile | Target | Result |
| --- | --- | --- |
| Production | SSD | Daily-use Ubuntu, repository checkout, and first-boot setup command |
| Rescue | eMMC | Minimal independent Rescue OS and recovery tooling |

Autoinstall can erase disks. Review the target serial or model before writing
media or booting the installer.

## Production USB

Build the complete installer USB from a repository checkout — this downloads
and verifies the Ubuntu Server ISO, writes a bootable UEFI USB (no Rufus
needed), and injects the autoinstall profile:

```bash
sudo ./lisa-edge usb build production --device /dev/sdX
```

On Windows (elevated prompt; find the disk number with `usb list`, or omit
it and pick from the interactive listing):

```bat
lisa-edge usb build production 2
```

If you already have a bootable Ubuntu installer USB, inject the profile only:

```bash
sudo ./lisa-edge usb prepare production --auto-detect
sudo ./lisa-edge usb prepare production /media/$USER/UBUNTU_USB
```

```bat
lisa-edge usb prepare production E:
```

The preparation wizard creates or validates the ignored, machine-specific file:

```text
install/usb/config/production/user-data
```

It asks for the SSH public key, target disk match rule, and Git release/ref.
`main` is suitable for development; production media should use a reviewed tag
or immutable commit.

The source template is:

```text
install/usb/config/production/user-data.template
```

Never commit generated `user-data`.

## Production first-boot flow

```text
prepare Ubuntu USB
  → boot target and wipe the reviewed SSD
  → install Ubuntu Server
  → clone repository to /opt/lisa-edge
  → install first-boot notification and lisa-edge-provision alias
  → reboot
  → connect with the configured SSH key or console
  → run sudo lisa-edge-provision
  → choose Fresh or Restore
  → review configuration and services
  → bootstrap, deploy, and validate
```

Autoinstall does not start production Compose services in installer
`late-commands`. Hardware paths, NAS access, secrets, service choices, and
restore confirmation remain in the interactive first-boot workflow.

## Rescue USB

First replace all placeholders in:

```text
install/usb/config/rescue/user-data.template
```

The rescue profile requires an explicit eMMC serial, SSH public key, and
password hash. It must not use `size: largest`.

Build the complete rescue USB on Linux:

```bash
sudo ./lisa-edge usb build rescue --device /dev/sdX
```

On Windows:

```bat
lisa-edge usb build rescue 2
```

Or inject the profile onto an existing installer USB:

```bash
sudo ./lisa-edge usb prepare rescue /media/$USER/UBUNTU_USB
```

```bat
lisa-edge usb prepare rescue E:
```

After installing the minimal OS, the template invokes:

```bash
/opt/lisa-edge/lisa-edge rescue bootstrap
```

Production services must not run on the Rescue OS. See the
[Rescue OS guide](../../rescue/README.md).

## Disk safety

Inspect candidate disks before generating either profile:

```bash
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TYPE,TRAN,MOUNTPOINTS
```

Also verify firmware boot order and disconnect unrelated removable storage when
practical. A correct hostname or USB label does not prove that the installer
selected the intended disk.
