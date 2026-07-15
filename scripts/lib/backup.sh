#!/usr/bin/env bash

lisa_verify_backup_checksum() {
  local archive="$1"
  local allow_missing="${2:-0}"
  local checksum_file="$archive.sha256"
  local expected actual extra

  if [ ! -f "$checksum_file" ]; then
    if [ "$allow_missing" = "1" ]; then
      echo "[LISA] WARNING: Restoring without a checksum because it was explicitly allowed." >&2
      return 0
    fi
    echo "Missing backup checksum: $checksum_file" >&2
    echo "Use --allow-missing-checksum only for a backup from a trusted source." >&2
    return 1
  fi

  expected="$(awk 'NR == 1 { print $1 }' "$checksum_file")"
  extra="$(awk 'NR > 1 && NF { count++ } END { print count + 0 }' "$checksum_file")"
  if ! [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || [ "$extra" -ne 0 ]; then
    echo "Invalid checksum sidecar: $checksum_file" >&2
    return 1
  fi

  actual="$(sha256sum "$archive" | awk '{ print $1 }')"
  if [ "${actual,,}" != "${expected,,}" ]; then
    echo "Backup checksum verification failed: $archive" >&2
    return 1
  fi

  echo "[LISA] Backup checksum verified."
}

lisa_read_validated_env_value() {
  local env_file="$1"
  local key="$2"
  local fallback="${3:-}"
  local line value

  line="$(grep -E "^${key}=" "$env_file" | tail -n 1 || true)"
  if [ -z "$line" ]; then
    printf '%s\n' "$fallback"
    return 0
  fi

  value="${line#*=}"
  case "$value" in
    \'*\') value="${value:1:${#value}-2}" ;;
    \"*\") value="${value:1:${#value}-2}" ;;
  esac
  printf '%s\n' "$value"
}
