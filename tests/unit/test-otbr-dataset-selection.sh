#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/services/otbr/dataset/lib.sh"

fail() {
  echo "OTBR DATASET SELECTION TEST ERROR: $*" >&2
  exit 1
}

# --- backup description sanitization ---
result="$(otbr_sanitize_backup_description "before office move")"
[ "$result" = "before-office-move" ] ||
  fail "spaces must become hyphens, got: $result"

result="$(otbr_sanitize_backup_description 'a/b\c:d*e?f"g<h>i|j')"
[ "$result" = "a_b_c_d_e_f_g_h_i_j" ] ||
  fail "invalid filename characters must become underscores, got: $result"

result="$(otbr_sanitize_backup_description "keep-safe_chars.v1")"
[ "$result" = "keep-safe_chars.v1" ] ||
  fail "allowed characters must be preserved, got: $result"

result="$(otbr_sanitize_backup_description "$(printf 'x%.0s' $(seq 1 300))" 219)"
[ "${#result}" -eq 219 ] ||
  fail "description must be truncated to the length limit, got ${#result} chars"

# Multi-byte input must come out as pure ASCII so byte length is predictable.
result="$(otbr_sanitize_backup_description "phòng khách tầng 2")"
printf '%s' "$result" | LC_ALL=C grep -Eq '^[A-Za-z0-9._-]*$' ||
  fail "sanitized description must be ASCII-safe, got: $result"

# Path traversal input must not survive as a path.
result="$(otbr_sanitize_backup_description "../../etc/passwd")"
case "$result" in
  */*) fail "sanitized description must not contain '/', got: $result" ;;
esac

result="$(otbr_sanitize_backup_description "")"
[ -z "$result" ] || fail "empty description must stay empty, got: $result"

# --- dataset backup discovery ---
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/otbr-dataset-test.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$WORK_DIR/nested"
printf '0e08\n' > "$WORK_DIR/thread-dataset-20260101T000000Z.hex"
sleep 0.01
printf '0e08\n' > "$WORK_DIR/nested/thread-dataset-20260102T000000Z.hex"
sleep 0.01
printf '0e08\n' > "$WORK_DIR/thread-dataset-20260103T000000Z-after-move.hex"
printf '0e08\n' > "$WORK_DIR/$OTBR_PENDING_DATASET_FILE_NAME"
ln -s "thread-dataset-20260103T000000Z-after-move.hex" "$WORK_DIR/latest.dataset.hex"

mapfile -t listed < <(otbr_list_dataset_backup_files "$WORK_DIR")
[ "${#listed[@]}" -eq 3 ] ||
  fail "expected 3 backups (no pending marker, no symlink), got ${#listed[@]}: ${listed[*]}"
[ "${listed[0]}" = "$WORK_DIR/thread-dataset-20260103T000000Z-after-move.hex" ] ||
  fail "backups must be listed newest first, got: ${listed[0]}"
for item in "${listed[@]}"; do
  case "$item" in
    *"$OTBR_PENDING_DATASET_FILE_NAME") fail "pending marker must be excluded from listing" ;;
    *latest.dataset.hex) fail "latest symlink must be excluded from listing" ;;
  esac
done

# --- dataset file validation ---
printf '0e080000000000010000\n' > "$WORK_DIR/valid.hex"
otbr_dataset_file_is_valid_hex "$WORK_DIR/valid.hex" ||
  fail "valid hex dataset must be accepted"

printf 'not-a-dataset\n' > "$WORK_DIR/invalid.hex"
if otbr_dataset_file_is_valid_hex "$WORK_DIR/invalid.hex"; then
  fail "non-hex dataset content must be rejected"
fi

printf '\n' > "$WORK_DIR/empty.hex"
if otbr_dataset_file_is_valid_hex "$WORK_DIR/empty.hex"; then
  fail "empty dataset file must be rejected"
fi

if otbr_dataset_file_is_valid_hex "$WORK_DIR/does-not-exist.hex"; then
  fail "missing dataset file must be rejected"
fi

echo "OTBR dataset selection tests passed."
