# Thread Border Router

LISA Edge supports OpenThread Border Router as an optional Docker Compose profile.

## Requirements

- Thread radio flashed with RCP firmware
- Stable `/dev/serial/by-id/...` device path
- IPv6 enabled on the host
- Correct backbone interface, usually the ZimaBoard service-facing NIC

## Find radio device

```bash
ls -l /dev/serial/by-id/
```

Set this in `.env`:

```env
THREAD_RADIO_DEVICE=/dev/serial/by-id/usb-YOUR-RCP-RADIO
OTBR_BACKBONE_IF=enp1s0
LISA_COMPOSE_SERVICES=otbr
```

## Deploy

```bash
sudo ./scripts/deploy.sh
```

## Notes

Use `openthread/border-router` for real deployments. Do not use `openthread/otbr` for production because it is marked as a testing/simulation image by Docker Hub.
