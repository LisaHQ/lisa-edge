#!/usr/bin/env bash

# Shared helpers for OTBR Thread dataset tooling. Sourced by dataset scripts
# and the OTBR provisioning wizard; keep this file free of side effects.

# One-shot markers staged by the provisioning wizard inside
# OTBR_DATASET_BACKUP_DIR and consumed by init-or-restore.sh on deploy.
# shellcheck disable=SC2034
OTBR_PENDING_DATASET_FILE_NAME="pending.dataset.hex"
# shellcheck disable=SC2034
OTBR_PENDING_NEW_NETWORK_FILE_NAME="pending.new-network"

# Maximum filename length on the supported filesystems (ext4 and friends).
OTBR_FILENAME_MAX_BYTES=255

# Sanitize a user-supplied backup description so it can be embedded in a
# filename: spaces become '-', any other byte outside [A-Za-z0-9._-] becomes
# '_', and the result is truncated to max_length bytes. The output is pure
# ASCII, so byte length equals character length.
otbr_sanitize_backup_description() {
  local description="${1-}"
  local max_length="${2:-64}"
  description="${description// /-}"
  description="$(printf '%s' "$description" | LC_ALL=C tr -c 'A-Za-z0-9._-' '_')"
  printf '%s' "${description:0:max_length}"
}

# Print Thread dataset backup candidates under a directory, newest first, one
# path per line. Regular *.hex files only: the latest.dataset.hex symlink is
# skipped (its target is already listed) and pending markers are excluded.
otbr_list_dataset_backup_files() {
  local search_root="$1"
  find "$search_root" -maxdepth 3 -type f -name '*.hex' \
    ! -name "$OTBR_PENDING_DATASET_FILE_NAME" -printf '%T@\t%p\n' 2>/dev/null |
    sort -rn | cut -f2-
}

# True when the dataset file contains a single non-empty hex string.
otbr_dataset_file_is_valid_hex() {
  local dataset_file="$1"
  [ -f "$dataset_file" ] || return 1
  tr -d '[:space:]' < "$dataset_file" | grep -Eq '^[0-9a-fA-F]+$'
}
