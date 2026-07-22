#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/services/matter-server/data/lib.sh"

fail() {
  echo "MATTER DATA SELECTION TEST ERROR: $*" >&2
  exit 1
}

# --- backup description sanitization ---
result="$(matter_sanitize_backup_description "before office move")"
[ "$result" = "before-office-move" ] ||
  fail "spaces must become hyphens, got: $result"

result="$(matter_sanitize_backup_description 'a/b\c:d*e?f"g<h>i|j')"
[ "$result" = "a_b_c_d_e_f_g_h_i_j" ] ||
  fail "invalid filename characters must become underscores, got: $result"

result="$(matter_sanitize_backup_description "keep-safe_chars.v1")"
[ "$result" = "keep-safe_chars.v1" ] ||
  fail "allowed characters must be preserved, got: $result"

result="$(matter_sanitize_backup_description "$(printf 'x%.0s' $(seq 1 300))" 219)"
[ "${#result}" -eq 219 ] ||
  fail "description must be truncated to the length limit, got ${#result} chars"

# Path traversal input must not survive as a path.
result="$(matter_sanitize_backup_description "../../etc/passwd")"
case "$result" in
  */*) fail "sanitized description must not contain '/', got: $result" ;;
esac

# --- data backup discovery ---
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matter-data-test.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

make_archive() {
  local out="$1"
  local content_dir
  content_dir="$(mktemp -d "$WORK_DIR/content.XXXXXX")"
  printf '{}\n' > "$content_dir/chip.json"
  tar -C "$content_dir" -czf "$out" .
  rm -rf "$content_dir"
}

mkdir -p "$WORK_DIR/nested"
make_archive "$WORK_DIR/matter-data-20260101T000000Z.tar.gz"
sleep 0.01
make_archive "$WORK_DIR/nested/matter-data-20260102T000000Z.tar.gz"
sleep 0.01
make_archive "$WORK_DIR/matter-data-20260103T000000Z-after-move.tar.gz"
make_archive "$WORK_DIR/$MATTER_PENDING_DATA_FILE_NAME"
ln -s "matter-data-20260103T000000Z-after-move.tar.gz" "$WORK_DIR/latest.matter-data.tar.gz"

mapfile -t listed < <(matter_list_data_backup_files "$WORK_DIR")
[ "${#listed[@]}" -eq 3 ] ||
  fail "expected 3 backups (no pending marker, no symlink), got ${#listed[@]}: ${listed[*]}"
[ "${listed[0]}" = "$WORK_DIR/matter-data-20260103T000000Z-after-move.tar.gz" ] ||
  fail "backups must be listed newest first, got: ${listed[0]}"
for item in "${listed[@]}"; do
  case "$item" in
    *"$MATTER_PENDING_DATA_FILE_NAME") fail "pending marker must be excluded from listing" ;;
    *latest.matter-data.tar.gz) fail "latest symlink must be excluded from listing" ;;
  esac
done

# --- archive validation ---
make_archive "$WORK_DIR/valid.tar.gz"
matter_data_archive_is_valid "$WORK_DIR/valid.tar.gz" ||
  fail "valid archive must be accepted"

printf 'not-a-tarball\n' > "$WORK_DIR/invalid.tar.gz"
if matter_data_archive_is_valid "$WORK_DIR/invalid.tar.gz"; then
  fail "non-tar.gz content must be rejected"
fi

if matter_data_archive_is_valid "$WORK_DIR/does-not-exist.tar.gz"; then
  fail "missing archive must be rejected"
fi

printf 'x\n' > "$WORK_DIR/escape-target"
mkdir -p "$WORK_DIR/sub"
tar -czPf "$WORK_DIR/absolute.tar.gz" "$WORK_DIR/escape-target"
if matter_data_archive_is_valid "$WORK_DIR/absolute.tar.gz"; then
  fail "archive with absolute member paths must be rejected"
fi

(cd "$WORK_DIR/sub" && tar -czPf "$WORK_DIR/traversal.tar.gz" ../escape-target)
if matter_data_archive_is_valid "$WORK_DIR/traversal.tar.gz"; then
  fail "archive with '..' member paths must be rejected"
fi

# --- data directory state detection ---
mkdir -p "$WORK_DIR/store"
if matter_data_dir_has_state "$WORK_DIR/store"; then
  fail "empty data directory must report no state"
fi
if matter_data_dir_has_state "$WORK_DIR/store-missing"; then
  fail "missing data directory must report no state"
fi
printf '{}\n' > "$WORK_DIR/store/chip.json"
matter_data_dir_has_state "$WORK_DIR/store" ||
  fail "non-empty data directory must report state"

echo "Matter data selection tests passed."
