#!/usr/bin/env bash
set -euo pipefail

echo "== LISA Edge Disk Detection =="
echo

echo "-- Block devices --"
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TYPE,TRAN,MOUNTPOINTS
echo

echo "-- Disk by-id entries --"
find /dev/disk/by-id -maxdepth 1 -type l -printf "%f -> %l\n" | sort || true
echo

echo "-- Candidate install targets --"
lsblk -dn -o NAME,PATH,SIZE,MODEL,SERIAL,TYPE,TRAN | awk '$6 == "disk" {print}'
echo

cat <<'EOF'
Notes:
- eMMC is usually smaller, around 64G on ZimaBoard 2.
- Production SSD is usually larger, for example 500G.
- For rescue autoinstall, prefer matching eMMC by serial.
- For production autoinstall, prefer matching SSD by serial or use size: largest only when you are sure no larger data disk is attached.
EOF
