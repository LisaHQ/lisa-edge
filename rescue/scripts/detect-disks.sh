#!/usr/bin/env bash
set -euo pipefail

echo "== LISA Edge Disk Detection =="
echo

echo "-- Block devices --"
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TYPE,TRAN,MOUNTPOINTS
echo

echo "-- Disk by-id entries --"
find /dev/disk/by-id -maxdepth 1 -type l -printf "%f -> %l\n" 2>/dev/null | sort || true
echo

echo "-- Candidate install targets --"
# TYPE must be matched from a spaceless column set: models like
# "Samsung SSD 870 EVO" contain spaces and break positional awk fields.
while IFS= read -r disk_path; do
  lsblk -dn -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN "$disk_path"
done < <(lsblk -dn -o PATH,TYPE | awk '$2 == "disk" {print $1}')
echo

cat <<'EOF'
Notes:
- eMMC is usually smaller, around 64G on ZimaBoard 2.
- Production SSD is usually larger, for example 500G.
- For rescue autoinstall, prefer matching eMMC by serial.
- For production autoinstall, prefer matching SSD by serial or use size: largest only when you are sure no larger data disk is attached.
EOF
