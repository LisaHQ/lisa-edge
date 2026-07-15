#!/usr/bin/env bash
set -euo pipefail

EDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-/tmp/lisa-edge-diag-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT_DIR"
cd "$EDGE_DIR"

{
  echo "# LISA Edge diagnostics"
  date -Is
  echo
  echo "## Host"
  hostnamectl || true
  uname -a || true
  echo
  echo "## Disk"
  df -h || true
  lsblk || true
  echo
  echo "## Network"
  ip -br addr || true
  ip route || true
  echo
  echo "## Docker"
  docker version || true
  docker ps -a || true
} > "$OUT_DIR/summary.txt" 2>&1

if [ -f .env ]; then
  cp .env "$OUT_DIR/env.redacted"
  sed -i -E 's/(PASSWORD|TOKEN|AUTHKEY|SECRET)=.*/\1=REDACTED/g' "$OUT_DIR/env.redacted"
fi

docker compose --env-file .env -f compose/docker-compose.yml ps > "$OUT_DIR/docker-compose-ps.txt" 2>&1 || true
journalctl -u lisa-edge.service -n 300 --no-pager > "$OUT_DIR/lisa-edge-journal.txt" 2>&1 || true
journalctl -u docker.service -n 300 --no-pager > "$OUT_DIR/docker-journal.txt" 2>&1 || true

tar -czf "$OUT_DIR.tar.gz" -C "$(dirname "$OUT_DIR")" "$(basename "$OUT_DIR")"
echo "Created diagnostics archive: $OUT_DIR.tar.gz"
