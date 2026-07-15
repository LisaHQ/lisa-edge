#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
TEMP_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TEMP_ROOT"; }
trap cleanup EXIT

FIXTURE="$TEMP_ROOT/fixture"
TARGET="$TEMP_ROOT/target"
REPO_MEMBER="${REPO_ROOT#/}"
mkdir -p "$FIXTURE/$REPO_MEMBER/compose" "$FIXTURE/$REPO_MEMBER/config" "$FIXTURE/srv/lisa-edge/data" "$FIXTURE/srv/lisa-edge/backups/otbr"
cp "$REPO_ROOT/.env.template" "$FIXTURE/$REPO_MEMBER/.env"
printf 'restored-data\n' > "$FIXTURE/srv/lisa-edge/data/integration.txt"
printf 'must-not-overwrite-live-code\n' > "$FIXTURE/$REPO_MEMBER/compose/blocked.txt"
printf 'dataset\n' > "$FIXTURE/srv/lisa-edge/backups/otbr/latest.dataset.hex"

ARCHIVE="$TEMP_ROOT/valid-backup.tar.gz"
tar -czf "$ARCHIVE" -C "$FIXTURE" \
  "$REPO_MEMBER/.env" \
  "$REPO_MEMBER/compose/blocked.txt" \
  "srv/lisa-edge/data/integration.txt" \
  "srv/lisa-edge/backups/otbr/latest.dataset.hex"
"$PYTHON_BIN" - "$ARCHIVE" <<'PY'
import hashlib
import pathlib
import sys

archive = pathlib.Path(sys.argv[1])
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_name(archive.name + ".sha256").write_text(f"{digest}  {archive.name}\n", encoding="ascii")
PY

LISA_EDGE_TESTING=1 LISA_RESTORE_TARGET_ROOT="$TARGET" PYTHON_BIN="$PYTHON_BIN" \
  bash "$REPO_ROOT/scripts/restore.sh" --no-deploy "$ARCHIVE"

test -f "$TARGET/$REPO_MEMBER/.env"
grep -q 'restored-data' "$TARGET/srv/lisa-edge/data/integration.txt"
grep -q 'dataset' "$TARGET/srv/lisa-edge/backups/otbr/latest.dataset.hex"
test ! -e "$TARGET/$REPO_MEMBER/compose/blocked.txt"

echo "Restore integration test passed."
