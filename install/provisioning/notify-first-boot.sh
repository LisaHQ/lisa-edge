#!/usr/bin/env bash
set -euo pipefail

MESSAGE='LISA Edge is waiting for provisioning. Run: sudo lisa-edge-provision'
MOTD_SCRIPT="/etc/update-motd.d/99-lisa-edge-provision"

cat > "$MOTD_SCRIPT" <<EOF
#!/bin/sh
echo '$MESSAGE'
EOF
chmod 0755 "$MOTD_SCRIPT"

if [ -w /dev/tty1 ]; then
  printf '\n%s\n\n' "$MESSAGE" > /dev/tty1 || true
fi

echo "$MESSAGE"
