# Hardware Model

LISA Edge is hardware-agnostic.

Any Linux host capable of running Docker can be used.

## Recommended Requirements

Minimum practical baseline:

- 64-bit Linux
- 2 CPU cores
- 2 GB RAM
- Stable storage
- Reliable network connection
- Docker support

Recommended baseline:

- 4 CPU cores
- 4 GB RAM or more
- SSD for Docker volumes
- UPS protection
- Wired Ethernet

## Reference Platform

The reference platform is ZimaBoard 2.

It is recommended because it is compact, low power, supports SATA storage, and can run Docker services reliably.

ZimaBoard is not required.

## Other Suitable Platforms

- Raspberry Pi 4 / 5
- Intel NUC
- Mini PC
- Generic x86-64 server
- Debian / Ubuntu VM
- Small Proxmox VM

## Storage Guidance

Avoid high-write workloads on weak embedded storage.

Recommended:

- OS on reliable local storage
- Docker volumes on SSD
- Backups on NAS or external storage
- Long-term logs outside the edge host

## Workloads to Avoid

Avoid using small edge hardware for:

- LLM inference
- ASR / TTS inference
- Heavy computer vision
- Video transcoding
- Large databases
- NAS-primary workloads
