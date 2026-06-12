#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
  curl \
  git \
  ca-certificates \
  htop \
  jq

#Package          Giữ?          Lý do
#-------------------------------------------------------------------------------------
#curl             ✅
#git              ✅            clone/pull repo
#ca-certificates  ✅            HTTPS/TLS
#openssh-server   ✅            Headless remote access (not need if user-data's SSH install-server is true)
#htop             ⚠️ optional    Debug
#jq               ⚠️ optional    Parse JSON script
#rsync            ⚠️ optional    backup/restore, will be installed by the 60-backup-tools.sh script
#ufw              ⚠️ optional    Not need if using UniFi network
#chrony           ⚠️ optional    Only need if Reference deployment work as NTP helper
#avahi-daemon     ⚠️ optional    Needed for mDNS/Thread/HomeKit discovery
#gnupg            ❌            Not need because will use get.docker.com
#lsb-release      ❌            Not need in current flow
