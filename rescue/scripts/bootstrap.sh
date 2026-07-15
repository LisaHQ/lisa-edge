#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESCUE_ROOT="${LISA_RESCUE_ROOT:-/opt/lisa-rescue}"

echo "[INFO] Bootstrapping LISA Edge Rescue OS..."

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    git \
    openssh-server \
    rsync \
    jq \
    htop \
    nano \
    vim-tiny \
    iproute2 \
    iputils-ping \
    dnsutils \
    net-tools \
    ethtool \
    pciutils \
    usbutils \
    lsof \
    ncdu \
    parted \
    gdisk \
    smartmontools \
    nvme-cli \
    hdparm \
    ufw

install -d -m 0755 "$RESCUE_ROOT"
install -d -m 0755 "$RESCUE_ROOT/scripts"
install -d -m 0755 "$RESCUE_ROOT/systemd"
install -d -m 0755 "$RESCUE_ROOT/logs"

while IFS= read -r -d '' script; do
    install -m 0755 "$script" "$RESCUE_ROOT/scripts/$(basename "$script")"
done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name '*.sh' -print0)

install -m 0644 "$SOURCE_ROOT/systemd/lisa-rescue-diagnostics.service" \
    "$RESCUE_ROOT/systemd/lisa-rescue-diagnostics.service"
install -m 0644 "$SOURCE_ROOT/systemd/lisa-rescue-diagnostics.timer" \
    "$RESCUE_ROOT/systemd/lisa-rescue-diagnostics.timer"

cat > "$RESCUE_ROOT/README.txt" <<'EOF'
LISA Edge Rescue OS

Useful commands:

  sudo /opt/lisa-rescue/scripts/diagnostics.sh
  sudo /opt/lisa-rescue/scripts/detect-disks.sh
  sudo /opt/lisa-rescue/scripts/mount-production.sh /dev/sdX2
  sudo /opt/lisa-rescue/scripts/restore-edge-backup.sh /path/to/archive.tar.gz
  sudo -E /opt/lisa-rescue/scripts/restore-filesystem-snapshot.sh
  sudo /opt/lisa-rescue/scripts/reinstall-guide.sh

The Rescue OS is independent of the production SSD.
Do not run production Docker services here.
EOF

systemctl enable ssh
systemctl restart ssh

echo "[INFO] Rescue scripts installed to $RESCUE_ROOT/scripts"
echo "[INFO] Rescue systemd assets installed to $RESCUE_ROOT/systemd"
echo "[INFO] SSH enabled."
echo "[INFO] Rescue bootstrap completed."
