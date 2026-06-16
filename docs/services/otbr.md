# OpenThread Border Router (OTBR)

> OTBR connects a Thread mesh network to the IP network.

## What is OTBR?

OTBR (OpenThread Border Router) is the bridge between:

* Your IP network (Ethernet/Wi-Fi)
* Your Thread mesh network

Examples:

- LISA Edge OTBR
- Home Assistant OTBR
- Apple Thread Border Router
- Google Thread Border Router

Multiple border routers may coexist, but dataset management must be handled carefully.

Without a Border Router, Thread devices cannot communicate with the rest of your smart home network.

> In LISA Edge, OTBR is an optional service for Matter-over-Thread environments.

## Role in LISA Edge

OTBR is important, but it is only one service in the LISA Edge stack.

Use OTBR when you need Thread devices or Matter-over-Thread devices.

## Requirements

- Thread radio flashed with RCP firmware
- Linux host / Docker
- Stable `/dev/serial/by-id/...` device path
- IPv6 enabled on the host
- Correct backbone interface, usually the Reference deployment service-facing NIC

Hardware Examples:
* nRF52840 USB Dongle
* Home Assistant SkyConnect (RCP mode)
* Sonoff ZBDongle-E (RCP mode)

> LISA Edge does not require ZimaBoard for OTBR. Any compatible Linux host may be used.

## Enable OTBR

Find radio device:

```bash
ls -l /dev/serial/by-id/
```

In `.env`:

```env
THREAD_RADIO_DEVICE=/dev/serial/by-id/usb-YOUR-RCP-RADIO
THREAD_RADIO_URL=spinel+hdlc+uart:///dev/ttyThreadRCP?uart-baudrate=460800
OTBR_BACKBONE_IF=enp1s0
LISA_COMPOSE_SERVICES="otbr"
```

Deploy:

```bash
sudo ./scripts/deploy.sh
```

**Notes**

Use `openthread/border-router` for real deployments. Do not use `openthread/otbr` for production because it is marked as a testing/simulation image by Docker Hub.


## Thread Dataset

The Thread Active Operational Dataset is the identity of the Thread network.

It contains sensitive network material (such as the Network Key and PSKc):

* Network Key
* PSKc
* Channel
* PAN ID
* Extended PAN ID
* Mesh Prefix

Think of it as:

* Wi-Fi SSID
* Wi-Fi password
* Router configuration

combined into one object.

Losing the dataset can require re-pairing Matter-over-Thread devices.

## IMPORTANT

If the dataset is lost:

* Existing Thread devices may stop working.
* Matter devices may need to be re-paired.
* Rebuilding OTBR alone does NOT restore the network.

The dataset must be backed up.

## Automatic Backup

LISA Edge includes:

* Dataset export
* Scheduled backups
* Restore automation

Backup file example:

```text
thread-dataset-20260612T031500Z.hex
```

Latest backup:

```text
latest.dataset.hex
```

## Disaster Recovery

Example:

* SSD fails
* ZimaBoard dies
* New server is deployed

Recovery process:

1. Install Linux.
2. Clone LISA Edge.
3. Restore `.env`.
4. Copy `latest.dataset.hex` to the OTBR backup directory.
5. Enable the OTBR service profile.
6. Deploy.

OTBR restores the dataset automatically.

Existing Thread devices reconnect without re-pairing.

## Production Recommendations

Recommended:

```env
OTBR_AUTO_RESTORE_DATASET=1
OTBR_AUTO_CREATE_NETWORK=0
```

Not recommended:

```env
OTBR_AUTO_CREATE_NETWORK=1
```

Reason:

If no dataset is detected, a brand-new Thread network could be created.

This may break all existing Thread devices.

## Backup Strategy

Recommended:

### Level 1

Local SSD

```text
/srv/lisa-edge/backups/otbr
```

### Level 2

NAS

```text
NAS:/Backups/LISA/OTBR
```

### Level 3

Offline archive

```text
Encrypted USB drive
```

## Migration to New Hardware

Supported migration path:

```text
Old server
↓
Backup dataset
↓
Deploy new server
↓
Restore dataset
↓
All Thread devices continue working
```

No re-pairing required.

## Security Considerations

Treat the Thread Dataset as a secret.

Anyone with access to the dataset may gain access to the Thread network.

Recommendations:

* Store backups with restricted permissions.
* Encrypt off-site backups.
* Never publish dataset files.
* Never commit dataset files to Git repositories.

## Recovery Guide

See:

- [OTBR Recovery](../operations/service-recovery/otbr.md)
- [Thread](../networking/thread.md)
- [Matter](../networking/matter.md)
