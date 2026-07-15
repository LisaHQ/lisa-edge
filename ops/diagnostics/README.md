# Diagnostics

This directory owns runtime evidence collection. Use:

```bash
sudo ./lisa-edge diagnostics
sudo ./lisa-edge diagnostics /path/to/output-directory
```

The command creates the requested directory and a matching `.tar.gz`. The
bundle contains host, disk, network and Docker summaries, selected Compose
status, recent `lisa-edge.service` journal entries, recent Docker journal entries
and a redacted copy of `.env` when present.

Common password, token, auth-key and secret values are redacted, but hostnames,
addresses, routes and other site metadata are not. Review the archive before
sharing it.

Use `sudo ./lisa-edge status` for a quick snapshot and
`sudo ./lisa-edge health` for active readiness tests. See the
[diagnostics runbook](../../docs/operations/diagnostics.md).
