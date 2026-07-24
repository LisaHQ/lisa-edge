#!/usr/bin/env bash

# Shared helpers for Matter fabric-data tooling. Sourced by the data scripts
# and the Matter provisioning wizard; keep this file free of side effects.
# Kept structurally in sync with services/otbr/dataset/lib.sh.

# One-shot markers staged by the provisioning wizard inside
# MATTER_DATA_BACKUP_DIR and consumed by init-or-restore.sh on deploy.
# shellcheck disable=SC2034
MATTER_PENDING_DATA_FILE_NAME="pending.matter-data.tar.gz"
# shellcheck disable=SC2034
MATTER_PENDING_RESET_FILE_NAME="pending.reset"

# Maximum filename length on the supported filesystems (ext4 and friends).
MATTER_FILENAME_MAX_BYTES=255

# The matterjs-server image defaults to a fixed non-root user (upstream
# Dockerfile: `USER 1000:1000`). Our compose overrides it to root because BLE
# commissioning needs effective HCI capabilities, but the store is still
# normalized to the image's default uid so it keeps working if that override
# is ever removed: under the default user, a root-owned store fails at
# startup with "EACCES: permission denied, mkdir '/data/config'".
MATTER_DATA_STORE_UID=1000
MATTER_DATA_STORE_GID=1000

# Make the Matter data store writable by the in-container server user. The
# data scripts run as root (via sudo through deploy or the CLI); without root
# (for example in unit tests) the chown cannot succeed and is skipped, since
# tests must never require privileges or mutate live ownership.
matter_data_set_store_ownership() {
  local data_dir="$1"
  [ "$(id -u)" -eq 0 ] || return 0
  chown -R "$MATTER_DATA_STORE_UID:$MATTER_DATA_STORE_GID" "$data_dir"
}

# Sanitize a user-supplied backup description so it can be embedded in a
# filename: spaces become '-', any other byte outside [A-Za-z0-9._-] becomes
# '_', and the result is truncated to max_length bytes. The output is pure
# ASCII, so byte length equals character length.
matter_sanitize_backup_description() {
  local description="${1-}"
  local max_length="${2:-64}"
  description="${description// /-}"
  description="$(printf '%s' "$description" | LC_ALL=C tr -c 'A-Za-z0-9._-' '_')"
  printf '%s' "${description:0:max_length}"
}

# Print Matter data backup candidates under a directory, newest first, one
# path per line. Regular *.tar.gz files only: the latest.matter-data.tar.gz
# symlink is skipped (its target is already listed) and pending markers are
# excluded.
matter_list_data_backup_files() {
  local search_root="$1"
  find "$search_root" -maxdepth 3 -type f -name '*.tar.gz' \
    ! -name "$MATTER_PENDING_DATA_FILE_NAME" -printf '%T@\t%p\n' 2>/dev/null |
    sort -rn | cut -f2-
}

# True when the archive is a readable non-empty tar.gz whose members are all
# safe relative paths (no absolute members, no '..' traversal, no symlinks
# escaping is enforced later by tar options at extraction time).
matter_data_archive_is_valid() {
  local archive_file="$1"
  local members member
  [ -f "$archive_file" ] || return 1
  members="$(tar -tzf "$archive_file" 2>/dev/null)" || return 1
  [ -n "$members" ] || return 1
  while IFS= read -r member; do
    case "/$member/" in
      //*) return 1 ;;      # absolute path
      */../*) return 1 ;;   # parent traversal
    esac
  done <<< "$members"
  return 0
}

# Verify an archive against its .sha256 sidecar when one exists. Returns 0
# when the sidecar is absent (hand-copied file) or matches, 1 on mismatch.
matter_data_archive_checksum_ok() {
  local archive_file="$1"
  local sidecar="$archive_file.sha256"
  local expected actual
  [ -f "$sidecar" ] || return 0
  expected="$(awk '{print $1; exit}' "$sidecar")"
  actual="$(sha256sum "$archive_file" | awk '{print $1}')"
  if [ "$expected" != "$actual" ]; then
    echo "Checksum mismatch for $archive_file (sidecar $sidecar)." >&2
    return 1
  fi
  return 0
}

# Write the .sha256 and .meta sidecars for a Matter data archive.
#   matter_data_write_archive_sidecars <archive> [label]
matter_data_write_archive_sidecars() {
  local archive_file="$1"
  local label="${2:-}"
  sha256sum "$archive_file" |
    awk -v name="$(basename "$archive_file")" '{print $1 "  " name}' \
      > "$archive_file.sha256"
  chmod 0600 "$archive_file.sha256"
  {
    echo "created_utc=$(date -u +%Y%m%dT%H%M%SZ)"
    echo "label=$label"
    echo "matter_server_image=${MATTER_SERVER_IMAGE:-}"
  } > "$archive_file.meta"
  chmod 0600 "$archive_file.meta"
}

# True when the Matter data directory contains persisted state worth
# protecting. An absent or empty directory means a fresh fabric would be
# created on the next start, so there is nothing to back up.
matter_data_dir_has_state() {
  local data_dir="$1"
  [ -d "$data_dir" ] || return 1
  [ -n "$(find "$data_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]
}
