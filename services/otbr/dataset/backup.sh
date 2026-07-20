#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$EDGE_REPO"

set -a
source ./.env
set +a

BACKUP_DIR="${OTBR_DATASET_BACKUP_DIR:-/srv/lisa-edge/backups/otbr}"
# shellcheck disable=SC1091
. "$EDGE_REPO/lib/paths.sh"
lisa_validate_persistent_path OTBR_DATASET_BACKUP_DIR "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
chmod 0700 "$BACKUP_DIR"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BACKUP_DIR/thread-dataset-$TS.hex"
LATEST="$BACKUP_DIR/latest.dataset.hex"
RETENTION_DAYS="${OTBR_DATASET_RETENTION_DAYS:-30}"

# otbr-agent may briefly drop control sessions right after dataset creation or
# deploy, so a single read can race an agent restart. Retry transient failures,
# but stop immediately when the agent confirms no dataset exists (NotFound).
DATASET=""
for _ in $(seq 1 10); do
  OUTPUT=""
  if OUTPUT="$(docker exec lisa-otbr ot-ctl dataset active -x 2>&1)"; then
    DATASET="$(printf '%s\n' "$OUTPUT" | awk '/^[0-9a-fA-F]+$/ {print $1; exit}')"
    [ -n "$DATASET" ] && break
  fi
  if printf '%s' "$OUTPUT" | grep -qi 'NotFound'; then
    echo "ERROR: OTBR has no active Thread dataset to back up." >&2
    echo "Form or restore a network first (deploy handles both), then rerun this backup." >&2
    exit 1
  fi
  sleep 3
done

if [ -z "$DATASET" ]; then
  {
    echo "ERROR: Could not read active Thread dataset from OTBR."
    echo "Inspect next:"
    echo "  docker exec lisa-otbr ot-ctl state"
    echo "  docker exec lisa-otbr ot-ctl dataset active -x"
    echo "Rerun this backup once ot-ctl answers consistently."
  } >&2
  exit 1
fi

printf '%s\n' "$DATASET" > "$OUT"
chmod 0600 "$OUT"
ln -sfn "$(basename "$OUT")" "$LATEST"

if [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] && [ "$RETENTION_DAYS" -gt 0 ]; then
  find "$BACKUP_DIR" -maxdepth 1 -type f -name 'thread-dataset-*.hex' \
    -mtime "+$RETENTION_DAYS" -delete
fi

echo "OTBR dataset backed up to: $OUT"
