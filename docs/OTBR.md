# OpenThread Border Router (OTBR)

## What is OTBR?

OTBR (OpenThread Border Router) is the bridge between:

* Your IP network (Ethernet/Wi-Fi)
* Your Thread mesh network

Without a Border Router, Thread devices cannot communicate with the rest of your smart home network.

In LISA Edge, OTBR is considered a critical infrastructure service.

---

## Hardware Requirements

OTBR requires:

- Linux
- Docker
- Supported Thread RCP radio

OTBR does NOT require ZimaBoard.
Any compatible Linux host may be used.

Recommended:

* ZimaBoard 2
* Ubuntu Server LTS
* Thread RCP radio

Examples:

* nRF52840 USB Dongle
* Home Assistant SkyConnect (RCP mode)
* Sonoff ZBDongle-E (RCP mode)

---

## Why Thread Matters

Thread is the preferred transport layer for Matter devices.

Benefits:

* Low power consumption
* Self-healing mesh network
* IPv6 native
* Local-first communication
* Vendor independent

Examples:

* Eve
* Nanoleaf
* Aqara Matter devices
* Future Matter sensors

---

## Understanding the Thread Dataset

The Thread Dataset is the identity of the network.

It contains:

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

---

## IMPORTANT

If the dataset is lost:

* Existing Thread devices may stop working.
* Matter devices may need to be re-paired.
* Rebuilding OTBR alone does NOT restore the network.

The dataset must be backed up.

---

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

---

## Disaster Recovery

Example:

* SSD fails
* ZimaBoard dies
* New server is deployed

Recovery process:

1. Install Ubuntu.
2. Clone lisa-edge.
3. Restore latest.dataset.hex.
4. Run deploy.sh.

OTBR restores the dataset automatically.

Existing Thread devices reconnect without re-pairing.

---

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

---

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

---

## Migration to New Hardware

Supported migration path:

Old ZimaBoard
↓
Backup dataset
↓
Deploy new server
↓
Restore dataset
↓
All Thread devices continue working

No re-pairing required.

---

## Security Considerations

Treat the Thread Dataset as a secret.

Anyone with access to the dataset may gain access to the Thread network.

Recommendations:

* Store backups with restricted permissions.
* Encrypt off-site backups.
* Never publish dataset files.
* Never commit dataset files to Git repositories.

---

## LISA Edge Architecture

Recommended placement:

ZimaBoard:

* OTBR
* MQTT
* NUT
* DNS helpers
* Infrastructure services

Heavy AI workloads should remain on dedicated servers.

OTBR should be considered a critical service and included in backup and disaster recovery plans.
