# USB Autoinstall Flow

LISA Edge has two Ubuntu Server installer profiles:

| Profile | Target | Result |
| --- | --- | --- |
| Production | SSD | Daily-use Ubuntu, repository checkout, and first-boot setup command |
| Rescue | eMMC | Minimal independent Rescue OS and recovery tooling |

Autoinstall can erase disks. Review the target serial or model before writing
media or booting the installer.

## Production USB

From a repository checkout on Linux:

```bash
sudo ./lisa-edge usb production --auto-detect
```

Or provide the mounted Ubuntu installer path:

```bash
sudo ./lisa-edge usb production /media/$USER/UBUNTU_USB
```

On Windows:

```bat
install\usb\production\scripts\prepare-ubuntu-usb.bat E:
```

The preparation wizard creates or validates the ignored, machine-specific file:

```text
install/usb/production/autoinstall/user-data
```

It asks for the SSH public key, target disk match rule, and Git release/ref.
`main` is suitable for development; production media should use a reviewed tag
or immutable commit.

The source template is:

```text
install/usb/production/autoinstall/user-data.template
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
install/usb/rescue/autoinstall/user-data.template
```

The rescue profile requires an explicit eMMC serial, SSH public key, and
password hash. It must not use `size: largest`.

Prepare the USB on Linux:

```bash
sudo ./lisa-edge usb rescue /media/$USER/UBUNTU_USB
```

Or on Windows:

```bat
install\usb\rescue\prepare-ubuntu-rescue-usb.bat E:
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
