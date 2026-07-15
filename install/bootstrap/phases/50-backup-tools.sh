#!/usr/bin/env bash
set -euo pipefail

echo "Installing backup tools..."

apt-get install -y rsync restic

DATA_ROOT="${DATA_ROOT:-/srv/lisa-edge}"
PHASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$PHASE_DIR/../../../lib/paths.sh"
lisa_validate_persistent_path DATA_ROOT "$DATA_ROOT"
mkdir -p "$DATA_ROOT"/backups

echo "Backup tools installed."
