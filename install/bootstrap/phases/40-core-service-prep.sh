#!/usr/bin/env bash
set -euo pipefail


###############################################################################
# Time sync
###############################################################################
echo "Installing Chrony time sync..."

apt-get install -y chrony

systemctl enable chrony
systemctl restart chrony

chronyc tracking || true

echo "Chrony configured."


###############################################################################
# Thread / OTBR host preparation
###############################################################################
# Thread/OTBR host preparation is optional.
# It is only needed when this host runs OpenThread Border Router.

PHASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$PHASE_DIR/../../.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_DIR/lib/compose.sh"

if ! lisa_has_service otbr && [ "${LISA_ENABLE_THREAD_HOST_PREP:-0}" != "1" ]; then
  echo "Skipping Thread host preparation. Enable with LISA_COMPOSE_SERVICES=otbr or LISA_ENABLE_THREAD_HOST_PREP=1."
  exit 0
fi

echo "Preparing host for Thread Border Router..."

apt-get install -y avahi-daemon

# OTBR needs IPv6 and forwarding enabled. These settings are safe even when OTBR profile is disabled.
cat >/etc/sysctl.d/lisa-thread.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.all.forwarding = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

systemctl enable avahi-daemon
systemctl restart avahi-daemon

echo "Thread host preparation completed."
