#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/recovery/scripts/recovery-safety.sh"

for unsafe in / /mnt /etc /mnt/../etc; do
  if recovery_validate_mount_path "$unsafe" >/dev/null 2>&1; then
    echo "Expected unsafe recovery path to be rejected: $unsafe" >&2
    exit 1
  fi
done

resolved="$(recovery_validate_mount_path /mnt/lisa-production)"
[ "$resolved" = "/mnt/lisa-production" ] || {
  echo "Unexpected safe recovery path resolution: $resolved" >&2
  exit 1
}

if recovery_refuse_overlapping_paths /mnt/lisa-production/backup /mnt/lisa-production >/dev/null 2>&1; then
  echo "Expected overlapping backup and production paths to be rejected." >&2
  exit 1
fi
if recovery_refuse_overlapping_paths /mnt /mnt/lisa-production >/dev/null 2>&1; then
  echo "Expected a production root inside the backup source to be rejected." >&2
  exit 1
fi

recovery_refuse_overlapping_paths /mnt/lisa-backup /mnt/lisa-production
echo "Recovery-safety tests passed."
