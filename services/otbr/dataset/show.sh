#!/usr/bin/env bash
set -euo pipefail

# Print OTBR's active Thread operational dataset as one hex TLV line
# (operator entry point: lisa-edge otbr dataset). The dataset contains the
# Thread network key: treat the output as a secret.

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# shellcheck disable=SC1091
. "$EDGE_REPO/lib/thread-dataset.sh"

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx lisa-otbr; then
  echo "ERROR: lisa-otbr container is not running." >&2
  echo "Start it with: sudo ./lisa-edge deploy" >&2
  exit 1
fi

DATASET_HEX="$(thread_otbr_active_dataset_hex_live)"
if [ -z "$DATASET_HEX" ]; then
  echo "ERROR: OTBR has no readable active dataset (agent still starting, or no network formed)." >&2
  echo "Inspect next: docker exec lisa-otbr ot-ctl state; docker logs --tail 50 lisa-otbr" >&2
  exit 1
fi

printf '%s\n' "$DATASET_HEX"
