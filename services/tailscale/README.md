# Tailscale VPN

- Selection key: `vpn-tailscale`
- Accepted alias: `tailscale`
- Enabled by default: no
- Container: `lisa-tailscale`

The service uses host networking and `/dev/net/tun`. Configure `TS_AUTHKEY` and
`TS_EXTRA_ARGS` with `sudo ./lisa-edge setup`, then run:

```bash
sudo ./lisa-edge deploy
sudo ./lisa-edge health
```

Tailnet state persists at `${DATA_ROOT}/docker/volumes/tailscale/` and is
included in full backups. Keep auth keys outside Git and use VPN instead of
publishing administrative dashboards to the internet.

Owned files: `compose.yml` and `provision.sh`. See
[operator reference](../../docs/services/vpn-tailscale.md).
