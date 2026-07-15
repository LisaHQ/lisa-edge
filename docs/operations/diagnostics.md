# Status, Health and Diagnostics

Use three levels of inspection:

```bash
sudo ./lisa-edge status       # selected services, containers and unit state
sudo ./lisa-edge health       # active readiness checks; nonzero on failure
sudo ./lisa-edge diagnostics  # collect an evidence bundle
```

`diagnostics` writes a timestamped directory and `.tar.gz` under `/tmp` unless
an output directory is supplied. It includes host, disk, network and Docker
summaries, Compose status, and recent LISA Edge and Docker journals. `.env` is
copied with common password/token/auth-key/secret values redacted.

Review every bundle before sharing it; hostnames, addresses, routes and other
site metadata remain visible. The implementation and exact contents are
documented in [`ops/diagnostics/`](../../ops/diagnostics/README.md).

Useful direct checks:

```bash
docker ps -a
journalctl -u lisa-edge.service -n 100 --no-pager
journalctl -u lisa-edge-backup.service -n 100 --no-pager
systemctl --failed
```

For service-specific expectations, use the matching page under
[`docs/services/`](../services/README.md).
