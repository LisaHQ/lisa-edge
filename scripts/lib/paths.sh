#!/usr/bin/env bash

lisa_validate_persistent_path() {
  local label="$1"
  local value="$2"

  case "$value" in
    ""|/) echo "$label cannot be empty or /." >&2; return 1 ;;
    /*) ;;
    *) echo "$label must be an absolute path: $value" >&2; return 1 ;;
  esac

  case "$value" in
    /var/lib/lisa-edge|/var/lib/lisa-edge/*) return 0 ;;
    /bin|/bin/*|/boot|/boot/*|/dev|/dev/*|/etc|/etc/*|/home|/home/*|\
    /lib|/lib/*|/lib64|/lib64/*|/opt|/opt/*|/proc|/proc/*|/root|/root/*|\
    /run|/run/*|/sbin|/sbin/*|/sys|/sys/*|/tmp|/tmp/*|/usr|/usr/*|/var|/var/*)
      echo "$label overlaps a protected system tree: $value" >&2
      return 1
      ;;
  esac
}
