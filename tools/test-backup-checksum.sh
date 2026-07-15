#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/backup.sh"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
ARCHIVE="$TEMP_DIR/lisa-edge-backup-test.tar.gz"

printf 'trusted backup payload\n' > "$ARCHIVE"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
lisa_verify_backup_checksum "$ARCHIVE" >/dev/null

printf 'corruption\n' >> "$ARCHIVE"
if lisa_verify_backup_checksum "$ARCHIVE" >/dev/null 2>&1; then
  echo "Expected checksum mismatch to fail." >&2
  exit 1
fi

rm -f "$ARCHIVE.sha256"
if lisa_verify_backup_checksum "$ARCHIVE" >/dev/null 2>&1; then
  echo "Expected missing checksum to fail." >&2
  exit 1
fi
lisa_verify_backup_checksum "$ARCHIVE" 1 >/dev/null 2>&1

echo "Backup-checksum tests passed."
