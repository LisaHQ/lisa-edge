#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TEMP_ROOT"; }
trap cleanup EXIT
mkdir -p "$TEMP_ROOT/mount/backups"

# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/paths.sh"

FAKE_TARGET=/
FAKE_SOURCE=/dev/root
findmnt() {
  case "$*" in
    *'-o TARGET'*) printf '%s\n' "$FAKE_TARGET" ;;
    *'-o SOURCE'*) printf '%s\n' "$FAKE_SOURCE" ;;
    *) return 1 ;;
  esac
}

if lisa_verify_mounted_destination "$TEMP_ROOT/mount/backups" >/dev/null 2>&1; then
  echo "Expected root-filesystem fallback to be rejected." >&2
  exit 1
fi

FAKE_TARGET="$TEMP_ROOT/mount"
FAKE_SOURCE='nas:/volume/lisa-edge'
lisa_verify_mounted_destination "$TEMP_ROOT/mount/backups" "$FAKE_SOURCE" >/dev/null
if lisa_verify_mounted_destination "$TEMP_ROOT/mount/backups" 'nas:/wrong' >/dev/null 2>&1; then
  echo "Expected wrong mount source to be rejected." >&2
  exit 1
fi

echo "Backup mount-guard tests passed."
