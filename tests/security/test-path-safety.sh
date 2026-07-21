#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/paths.sh"

for unsafe in /srv/../etc /srv/./data; do
  if lisa_validate_persistent_path TEST_PATH "$unsafe" >/dev/null 2>&1; then
    echo "Expected traversal path to be rejected: $unsafe" >&2
    exit 1
  fi
done

lisa_validate_persistent_path TEST_PATH /srv/lisa-edge
lisa_validate_persistent_path TEST_PATH /var/lib/lisa-edge

# On filesystems that permit symlinks, ensure an apparently non-system parent
# cannot redirect persistent writes into a protected tree.
TEMP_ROOT="$(mktemp -d "$REPO_ROOT/.path-safety.XXXXXX")"
cleanup() { rm -rf "$TEMP_ROOT"; }
trap cleanup EXIT
if ln -s /etc "$TEMP_ROOT/safe-parent" 2>/dev/null; then
  if symlink_output="$(lisa_validate_persistent_path \
    TEST_PATH "$TEMP_ROOT/safe-parent/lisa-edge" 2>&1)"
  then
    echo "Expected symlink into /etc to be rejected." >&2
    exit 1
  fi
  grep -q -- '-> /etc' <<<"$symlink_output" || {
    echo "Symlink rejection did not report the resolved protected path." >&2
    exit 1
  }
else
  echo "SKIP: filesystem does not permit creating the symlink safety fixture."
fi

echo "Persistent-path traversal and symlink safety tests passed."
