#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="/opt/lisa-rescue/logs"
mkdir -p "$LOG_DIR"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$LOG_DIR/diagnostics-$STAMP.log"

{
    echo "== LISA Edge Rescue Diagnostics =="
    echo "Timestamp UTC: $STAMP"
    echo

    echo "== Host =="
    hostnamectl || true
    uname -a
    uptime
    echo

    echo "== Network =="
    ip addr
    echo
    ip route
    echo
    resolvectl status || true
    echo

    echo "== Disks =="
    lsblk -o NAME,PATH,SIZE,FSTYPE,MODEL,SERIAL,TYPE,TRAN,MOUNTPOINTS
    echo

    echo "== Disk by-id =="
    find /dev/disk/by-id -maxdepth 1 -type l -printf "%f -> %l\n" | sort || true
    echo

    echo "== SMART summary =="
    for disk in $(lsblk -dn -o PATH,TYPE | awk '$2=="disk"{print $1}'); do
        echo "-- $disk --"
        smartctl -H "$disk" || true
        echo
    done

    echo "== PCI =="
    lspci || true
    echo

    echo "== USB =="
    lsusb || true
    echo

    echo "== Systemd failed units =="
    systemctl --failed || true
    echo

    echo "== Journal recent errors =="
    journalctl -p err -n 100 --no-pager || true
} | tee "$LOG_FILE"

echo
echo "Diagnostics saved to: $LOG_FILE"
