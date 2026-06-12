#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

set -a
source ./.env
set +a

BACKUP_DIR="${OTBR_DATASET_BACKUP_DIR:-/srv/lisa-edge/backups/otbr}"
mkdir -p "$BACKUP_DIR"
chmod 0700 "$BACKUP_DIR"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BACKUP_DIR/thread-dataset-$TS.hex"
LATEST="$BACKUP_DIR/latest.dataset.hex"

DATASET="$(docker exec lisa-otbr ot-ctl dataset active -x | awk '/^[0-9a-fA-F]+$/ {print $1; exit}')"

if [ -z "$DATASET" ]; then
  echo "ERROR: Could not read active Thread dataset from OTBR." >&2
  exit 1
fi

printf '%s\n' "$DATASET" > "$OUT"
chmod 0600 "$OUT"
ln -sfn "$OUT" "$LATEST"

echo "OTBR dataset backed up to: $OUT"