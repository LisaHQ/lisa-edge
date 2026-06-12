#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

set -a
source ./.env
set +a

LATEST="${OTBR_DATASET_LATEST:-/srv/lisa-edge/backups/otbr/latest.dataset.hex}"

echo "Waiting for OTBR container..."
for _ in $(seq 1 60); do
  if docker ps --format '{{.Names}}' | grep -qx lisa-otbr; then
    break
  fi
  sleep 2
done

CURRENT="$(docker exec lisa-otbr ot-ctl dataset active -x 2>/dev/null | awk '/^[0-9a-fA-F]+$/ {print $1; exit}' || true)"

if [ -n "$CURRENT" ]; then
  echo "OTBR already has active dataset. Backing it up."
  "$EDGE_REPO/scripts/otbr-backup-dataset.sh"
  exit 0
fi

if [ "${OTBR_AUTO_RESTORE_DATASET:-1}" = "1" ] && [ -f "$LATEST" ]; then
  echo "No active dataset found. Restoring latest dataset."
  "$EDGE_REPO/scripts/otbr-restore-dataset.sh" "$LATEST"
  exit 0
fi

if [ "${OTBR_AUTO_CREATE_NETWORK:-0}" = "1" ]; then
  echo "No dataset found. Creating a new Thread network."
  docker exec lisa-otbr ot-ctl dataset init new
  docker exec lisa-otbr ot-ctl dataset commit active
  docker exec lisa-otbr ot-ctl ifconfig up
  docker exec lisa-otbr ot-ctl thread start
  sleep 8
  "$EDGE_REPO/scripts/otbr-backup-dataset.sh"
  exit 0
fi

echo "ERROR: No active dataset and no backup found."
echo "Refusing to auto-create a new Thread network unless OTBR_AUTO_CREATE_NETWORK=1."
exit 1