#!/usr/bin/env bash

lisa_validate_persistent_path() {
  local label="$1"
  local value="$2"
  local resolved

  case "$value" in
    ""|/) echo "$label cannot be empty or /." >&2; return 1 ;;
    /*) ;;
    *) echo "$label must be an absolute path: $value" >&2; return 1 ;;
  esac

  case "/$value/" in
    */../*|*/./*)
      echo "$label cannot contain . or .. path components: $value" >&2
      return 1
      ;;
  esac

  command -v readlink >/dev/null 2>&1 || {
    echo "readlink is required to validate $label safely." >&2
    return 1
  }
  resolved="$(readlink -m -- "$value")" || {
    echo "Cannot resolve $label: $value" >&2
    return 1
  }

  case "$resolved" in
    ""|/) echo "$label resolves to an unsafe path: $resolved" >&2; return 1 ;;
    /var/lib/lisa-edge|/var/lib/lisa-edge/*|/run/media/*) return 0 ;;
    /bin|/bin/*|/boot|/boot/*|/dev|/dev/*|/etc|/etc/*|/home|/home/*|\
    /lib|/lib/*|/lib64|/lib64/*|/opt|/opt/*|/proc|/proc/*|/root|/root/*|\
    /run|/run/*|/sbin|/sbin/*|/sys|/sys/*|/tmp|/tmp/*|/usr|/usr/*|/var|/var/*)
      echo "$label overlaps a protected system tree after resolution: $value -> $resolved" >&2
      return 1
      ;;
  esac
}

lisa_verify_mounted_destination() {
  local destination="$1"
  local expected_source="${2:-}"
  local mount_target mount_source resolved_destination resolved_target

  command -v findmnt >/dev/null 2>&1 || {
    echo "findmnt is required when BACKUP_REQUIRE_MOUNT=1." >&2
    return 1
  }
  [ -d "$destination" ] || {
    echo "Required mounted backup destination does not exist: $destination" >&2
    return 1
  }

  mount_target="$(findmnt -rn -T "$destination" -o TARGET 2>/dev/null || true)"
  mount_source="$(findmnt -rn -T "$destination" -o SOURCE 2>/dev/null || true)"
  [ -n "$mount_target" ] && [ "$mount_target" != "/" ] || {
    echo "Backup destination is not on a dedicated mounted filesystem: $destination" >&2
    return 1
  }

  resolved_destination="$(readlink -f -- "$destination")"
  resolved_target="$(readlink -f -- "$mount_target")"
  case "$resolved_destination/" in
    "$resolved_target/"*) ;;
    *) echo "Backup destination is outside detected mountpoint: $mount_target" >&2; return 1 ;;
  esac

  if [ -n "$expected_source" ] && [ "$mount_source" != "$expected_source" ]; then
    echo "Unexpected backup mount source: $mount_source (expected $expected_source)" >&2
    return 1
  fi

  printf '%s\t%s\n' "$mount_source" "$mount_target"
}
