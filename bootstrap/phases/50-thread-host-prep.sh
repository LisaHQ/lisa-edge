#!/usr/bin/env bash
set -euo pipefail
# OTBR needs IPv6 and forwarding enabled. These settings are safe even when OTBR profile is disabled.
cat >/etc/sysctl.d/99-lisa-edge-thread.conf <<'EOC'
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOC
sysctl --system >/dev/null
