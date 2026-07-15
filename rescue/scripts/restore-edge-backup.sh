#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<EOF
Usage: sudo $0 <lisa-edge-backup.tar.gz> [production-root]

The production root defaults to /mnt/lisa-production. It must already be a
dedicated mountpoint below /mnt.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi
if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    usage
    exit 1
fi
if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root." >&2
    exit 1
fi

ARCHIVE="$1"
PRODUCTION_ROOT="${2:-${PRODUCTION_ROOT:-/mnt/lisa-production}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/recovery-safety.sh"

if [[ ! -f "$ARCHIVE" ]]; then
    echo "ERROR: LISA Edge backup archive not found: $ARCHIVE" >&2
    exit 1
fi
if [[ ! -d "$PRODUCTION_ROOT" ]]; then
    echo "ERROR: Production root does not exist: $PRODUCTION_ROOT" >&2
    echo "Mount it first with mount-production.sh." >&2
    exit 1
fi

ARCHIVE="$(readlink -f -- "$ARCHIVE")"
PRODUCTION_ROOT="$(recovery_validate_mount_path "$PRODUCTION_ROOT")"
recovery_require_exact_mount "$PRODUCTION_ROOT"
recovery_refuse_overlapping_paths "$ARCHIVE" "$PRODUCTION_ROOT"

resolve_lisa_edge_cli() {
    local checkout_root candidate

    if [[ -n "${LISA_EDGE_CLI:-}" ]]; then
        printf '%s\n' "$LISA_EDGE_CLI"
        return 0
    fi

    checkout_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
    for candidate in \
        "$checkout_root/lisa-edge" \
        "/opt/lisa-edge/lisa-edge" \
        "$PRODUCTION_ROOT/opt/lisa-edge/lisa-edge"
    do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    if command -v lisa-edge >/dev/null 2>&1; then
        command -v lisa-edge
        return 0
    fi

    echo "ERROR: Cannot find the lisa-edge command facade." >&2
    echo "Set LISA_EDGE_CLI to its absolute path." >&2
    return 1
}

LISA_EDGE_CLI="$(resolve_lisa_edge_cli)"

echo "[INFO] LISA Edge archive restore"
echo "  archive: $ARCHIVE"
echo "  target:  $PRODUCTION_ROOT"
echo "  command: $LISA_EDGE_CLI"
echo
echo "[INFO] Containers will not be deployed into the mounted target."
read -r -p "Type RESTORE to continue: " CONFIRM
if [[ "$CONFIRM" != "RESTORE" ]]; then
    echo "Aborted."
    exit 1
fi

exec bash "$LISA_EDGE_CLI" restore --target-root "$PRODUCTION_ROOT" "$ARCHIVE"
