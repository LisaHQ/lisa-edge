#!/usr/bin/env bash
set -euo pipefail

echo
echo "========================================"
echo "LISA Edge Disk Detection"
echo "========================================"
echo

echo "-- Block devices --"
lsblk -o NAME,PATH,SIZE,FSTYPE,MODEL,SERIAL,TYPE,TRAN,MOUNTPOINTS
echo

echo "-- Disk by-id entries --"
if [[ -d /dev/disk/by-id ]]; then
    find /dev/disk/by-id -maxdepth 1 -type l -printf "%f -> %l\n" | sort
else
    echo "/dev/disk/by-id not found"
fi
echo

echo "-- Candidate disks --"
lsblk -dn -o PATH,SIZE,MODEL,SERIAL,TYPE,TRAN | awk '$5 == "disk" {print}'
echo

cat <<'EOF'
Guidance:

Production Layer:
  - Should be installed on SSD.
  - Prefer matching by SSD serial in autoinstall.
  - size: largest is acceptable only when no larger data disk is attached.

Rescue Layer:
  - Should be installed on eMMC (or USB).
  - Always match eMMC (or USB) explicitly by serial.
  - Do not use size: largest for rescue installation.

For example, ZimaBoard 2 layout:
  eMMC  -> Rescue OS
  SSD   -> Production OS and Docker data
EOF
