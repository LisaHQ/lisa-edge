#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESCUE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

install -m 0644 "$RESCUE_DIR/systemd/lisa-rescue-diagnostics.service" /etc/systemd/system/
install -m 0644 "$RESCUE_DIR/systemd/lisa-rescue-diagnostics.timer" /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now lisa-rescue-diagnostics.timer

echo "[INFO] Diagnostics timer installed."
