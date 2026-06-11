#!/usr/bin/env bash
set -euo pipefail
systemctl enable ssh
install -d -m 0755 /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/99-lisa-edge.conf <<'EOC'
PasswordAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
X11Forwarding no
EOC
systemctl reload ssh || systemctl restart ssh
