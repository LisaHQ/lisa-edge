#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Unknown arguments must be rejected before any git or deploy action runs.
set +e
OUTPUT="$(bash "$REPO_ROOT/ops/deploy/update.sh" bogus 2>&1)"
STATUS=$?
set -e

if [ "$STATUS" -ne 2 ]; then
  echo "Expected exit status 2 for an unknown update argument, got $STATUS." >&2
  exit 1
fi

case "$OUTPUT" in
  *"Usage: lisa-edge update [clean]"*) ;;
  *)
    echo "Expected a usage message for an unknown update argument." >&2
    echo "Got: $OUTPUT" >&2
    exit 1
    ;;
esac

echo "Update argument validation tests passed."
