#!/usr/bin/env bash

# Shared path and mount guardrails for Rescue OS workflows. The recovery_*
# function names are retained as a public compatibility surface.

recovery_canonical_path() {
    readlink -m -- "$1"
}

recovery_validate_mount_path() {
    local requested="$1"
    local resolved

    case "$requested" in
        /mnt/*) ;;
        *) echo "ERROR: Recovery mount paths must be below /mnt: $requested" >&2; return 1 ;;
    esac

    resolved="$(recovery_canonical_path "$requested")"
    case "$resolved" in
        /mnt/*) ;;
        *) echo "ERROR: Unsafe recovery path after resolution: $resolved" >&2; return 1 ;;
    esac
    [ "$resolved" != "/mnt" ] || {
        echo "ERROR: /mnt itself cannot be used as a recovery root." >&2
        return 1
    }
    printf '%s\n' "$resolved"
}

recovery_require_exact_mount() {
    local path="$1"
    local mounted_target

    mounted_target="$(findmnt -rn -M "$path" -o TARGET 2>/dev/null || true)"
    if [ "$mounted_target" != "$path" ]; then
        echo "ERROR: Production root is not a dedicated mountpoint: $path" >&2
        return 1
    fi
}

recovery_refuse_overlapping_paths() {
    local source="$1"
    local destination="$2"
    case "$source/" in
        "$destination/"*)
            echo "ERROR: Backup source cannot be inside the production root." >&2
            return 1
            ;;
    esac
    case "$destination/" in
        "$source/"*)
            echo "ERROR: Production root cannot be inside the backup source." >&2
            return 1
            ;;
    esac
}
