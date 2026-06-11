#!/usr/bin/env bash
set -euo pipefail
EDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$EDGE_DIR/.env"
TS="$(date +%Y%m%d-%H%M%S)"
DEST="${BACKUP_DEST:-$DATA_ROOT/backups/lisa-edge-$TS.tar.gz}"
tar --exclude='*/log/*' -czf "$DEST" "$EDGE_DIR" "$DATA_ROOT/docker/volumes"
echo "$DEST"
