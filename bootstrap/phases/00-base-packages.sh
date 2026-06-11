#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
  curl \
  git \
  ca-certificates \
  openssh-server \
  htop \
  jq \
  rsync

#Package			Giữ?			Lý do
#----------------------------------------------------------------------------------------
#curl				✅				tải Docker installer, healthcheck
#git				✅				clone/pull repo
#ca-certificates	✅				HTTPS/TLS
#openssh-server		✅				headless remote access
#htop				⚠️ optional		tiện debug, không bắt buộc
# jq				⚠️ optional		parse JSON script, chưa cần thì bỏ
#rsync				⚠️ optional		backup/restore, nên chuyển sang backup script install
#ufw				⚠️ optional		nếu firewall chính là UniFi thì không bắt buộc
#chrony				⚠️ optional		chỉ cần nếu ZimaBoard làm NTP helper
#avahi-daemon		⚠️ optional		chỉ cần nếu cần mDNS/Thread/HomeKit discovery
#gnupg				❌				không cần nếu dùng get.docker.com
#lsb-release		❌				không cần trong flow hiện tại
