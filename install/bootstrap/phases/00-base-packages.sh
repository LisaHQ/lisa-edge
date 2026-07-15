#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
  curl \
  git \
  ca-certificates \
  python3 \
  htop \
  jq

# Base package policy:
#
# Required:
#   curl             Download bootstrap installers and remote resources.
#   git              Clone and update the LISA Edge repository.
#   ca-certificates  Validate HTTPS/TLS connections.
#
# Useful for operations:
#   htop             Interactive troubleshooting.
#   jq               JSON parsing for future scripts.
#
# Installed by other bootstrap phases when needed:
#   rsync/restic     Backup and restore tooling.
#   chrony           Time synchronization.
#   avahi-daemon     mDNS / Thread / HomeKit discovery support.
#
# Not installed here:
#   openssh-server   Normally installed by Ubuntu autoinstall user-data.
#   ufw              Firewall policy is deployment-specific.
