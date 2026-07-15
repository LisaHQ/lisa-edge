#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$EDGE_REPO/.env"

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }
[ -f "$ENV_FILE" ] || { echo "Missing $ENV_FILE" >&2; exit 1; }

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

ADMIN_USER="${LISA_ADMIN_USER:-lisa}"
SUDOERS_FILE="/etc/sudoers.d/90-lisa-admin"

case "${LISA_KEEP_PASSWORDLESS_SUDO:-0}" in
  1)
    echo "[LISA] WARNING: passwordless sudo remains enabled for $ADMIN_USER by explicit configuration." >&2
    exit 0
    ;;
  0) ;;
  *) echo "LISA_KEEP_PASSWORDLESS_SUDO must be 0 or 1." >&2; exit 1 ;;
esac

[ -e "$SUDOERS_FILE" ] || exit 0
id "$ADMIN_USER" >/dev/null 2>&1 || {
  echo "Configured admin account does not exist: $ADMIN_USER" >&2
  exit 1
}

password_status="$(passwd -S "$ADMIN_USER" 2>/dev/null | awk '{print $2}')"
if [ "$password_status" != "P" ]; then
  [ -t 0 ] && [ -t 1 ] || {
    echo "Cannot remove passwordless sudo: $ADMIN_USER has no usable password and bootstrap is non-interactive." >&2
    echo "Run sudo passwd $ADMIN_USER, then rerun this script." >&2
    exit 1
  }
  echo "[LISA] Set a local password for $ADMIN_USER before passwordless sudo is removed."
  passwd "$ADMIN_USER"
  password_status="$(passwd -S "$ADMIN_USER" 2>/dev/null | awk '{print $2}')"
  [ "$password_status" = "P" ] || {
    echo "Password for $ADMIN_USER is still unavailable; passwordless sudo was preserved." >&2
    exit 1
  }
fi

if command -v visudo >/dev/null 2>&1; then
  visudo -cf /etc/sudoers >/dev/null
fi
rm -f "$SUDOERS_FILE"
echo "[LISA] Temporary passwordless sudo grant removed for $ADMIN_USER."
