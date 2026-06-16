#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESCUE_ROOT="/opt/lisa-rescue"

echo "[INFO] Bootstrapping LISA Edge Rescue Layer..."

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
install -d -m 0755 "$RESCUE_ROOT/logs"

cp "$SCRIPT_DIR"/*.sh "$RESCUE_ROOT/scripts/"
chmod +x "$RESCUE_ROOT/scripts/"*.sh

cat > "$RESCUE_ROOT/README.txt" <<'EOF'
LISA Edge Rescue Layer

Useful commands:

  sudo /opt/lisa-rescue/scripts/diagnostics.sh
  sudo /opt/lisa-rescue/scripts/detect-disks.sh
  sudo /opt/lisa-rescue/scripts/mount-production.sh /dev/sdX2
  sudo /opt/lisa-rescue/scripts/restore-production.sh
  sudo /opt/lisa-rescue/scripts/reinstall-production.sh

This rescue environment should stay minimal.
Do not run production Docker services here.
EOF

systemctl enable ssh
systemctl restart ssh

echo "[INFO] Rescue scripts installed to $RESCUE_ROOT/scripts"
echo "[INFO] SSH enabled."
echo "[INFO] Rescue bootstrap completed."
