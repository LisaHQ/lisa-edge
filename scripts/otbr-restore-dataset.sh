#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

set -a
source ./.env
set +a

DATASET_FILE="${1:-${OTBR_DATASET_LATEST:-/srv/lisa-edge/backups/otbr/latest.dataset.hex}}"

if [ ! -f "$DATASET_FILE" ]; then
  echo "ERROR: Dataset file not found: $DATASET_FILE" >&2
  exit 1
fi

DATASET="$(tr -d '[:space:]' < "$DATASET_FILE")"

if ! echo "$DATASET" | grep -Eq '^[0-9a-fA-F]+$'; then
  echo "ERROR: Dataset file is not valid hex." >&2
  exit 1
fi

docker exec lisa-otbr ot-ctl thread stop || true
docker exec lisa-otbr ot-ctl ifconfig down || true
docker exec lisa-otbr ot-ctl dataset clear || true
docker exec lisa-otbr ot-ctl dataset set active "$DATASET"
docker exec lisa-otbr ot-ctl ifconfig up
docker exec lisa-otbr ot-ctl thread start

sleep 8
docker exec lisa-otbr ot-ctl state

echo "OTBR dataset restored from: $DATASET_FILE"