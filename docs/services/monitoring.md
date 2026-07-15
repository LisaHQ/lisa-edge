# Monitoring

LISA Edge includes Uptime Kuma by default for lightweight continuous monitoring.
See [Uptime Kuma](uptime-kuma.md) for deployment and storage details.

Operator checks remain separate from dashboards:

```bash
sudo ./lisa-edge status
sudo ./lisa-edge health
sudo ./lisa-edge diagnostics
```

Use Uptime Kuma for service availability and the CLI for deployment readiness
and evidence collection. Monitor MQTT, OTBR, VPN, LISA Brain endpoints and any
site-critical dashboards. Avoid high-write observability stacks on edge storage;
send long-term metrics and logs to a dedicated system.
