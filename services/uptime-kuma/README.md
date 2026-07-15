# Uptime Kuma

- Selection key: `uptime-kuma`
- Enabled by default: yes
- Container: `lisa-uptime`
- UI: `UPTIME_KUMA_BIND_ADDR:UPTIME_KUMA_PORT`, default `127.0.0.1:3001`

Configure it with `sudo ./lisa-edge setup`, then run:

```bash
sudo ./lisa-edge deploy
sudo ./lisa-edge health
```

Persistent monitors and application state live at
`${DATA_ROOT}/docker/volumes/uptime-kuma/` and are included in full backups.
Use VPN or a trusted bind address for remote access.

Owned files: `compose.yml` and `provision.sh`. See
[operator reference](../../docs/services/uptime-kuma.md).
