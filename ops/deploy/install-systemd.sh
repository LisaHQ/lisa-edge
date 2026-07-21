#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

install_unit() {
  local src="$1"
  local dst="$2"

  sed "s|/opt/lisa-edge|$EDGE_REPO|g" "$src" > "$dst"
  chmod 0644 "$dst"
}

first_existing_file() {
  local candidate
  for candidate in "$@"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

install_unit "$EDGE_REPO/ops/deploy/systemd/lisa-edge.service" /etc/systemd/system/lisa-edge.service
install_unit "$EDGE_REPO/ops/backup-restore/systemd/lisa-edge-backup.service" /etc/systemd/system/lisa-edge-backup.service
install_unit "$EDGE_REPO/ops/backup-restore/systemd/lisa-edge-backup.timer" /etc/systemd/system/lisa-edge-backup.timer

FIRST_BOOT_UNIT="$(first_existing_file \
  "$EDGE_REPO/install/provisioning/systemd/lisa-first-boot.service" \
  "$EDGE_REPO/provisioning/systemd/lisa-first-boot.service" || true)"
if [ -n "$FIRST_BOOT_UNIT" ]; then
  install_unit "$FIRST_BOOT_UNIT" /etc/systemd/system/lisa-first-boot.service
fi

chmod 0755 "$EDGE_REPO/lisa-edge"
ln -sfn "$EDGE_REPO/lisa-edge" /usr/local/sbin/lisa-edge
ln -sfn "$EDGE_REPO/lisa-edge" /usr/local/sbin/lisa-edge-provision

OTBR_BACKUP_SERVICE="$(first_existing_file \
  "$EDGE_REPO/services/otbr/systemd/lisa-otbr-dataset-backup.service" \
  "$EDGE_REPO/systemd/lisa-otbr-dataset-backup.service" || true)"
if [ -n "$OTBR_BACKUP_SERVICE" ]; then
  install_unit "$OTBR_BACKUP_SERVICE" /etc/systemd/system/lisa-otbr-dataset-backup.service
fi

OTBR_BACKUP_TIMER="$(first_existing_file \
  "$EDGE_REPO/services/otbr/systemd/lisa-otbr-dataset-backup.timer" \
  "$EDGE_REPO/systemd/lisa-otbr-dataset-backup.timer" || true)"
if [ -n "$OTBR_BACKUP_TIMER" ]; then
  install_unit "$OTBR_BACKUP_TIMER" /etc/systemd/system/lisa-otbr-dataset-backup.timer
fi

systemctl daemon-reload
systemctl enable lisa-edge.service
systemctl enable lisa-edge-backup.timer
systemctl start lisa-edge-backup.timer

if [ -f /etc/systemd/system/lisa-otbr-dataset-backup.timer ]; then
  if [ -f "$EDGE_REPO/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$EDGE_REPO/.env"
    set +a
    # shellcheck disable=SC1091
    . "$EDGE_REPO/lib/compose.sh"
    if lisa_has_service otbr; then
      systemctl enable --now lisa-otbr-dataset-backup.timer
      echo "OTBR dataset backup timer enabled."
    else
      systemctl disable --now lisa-otbr-dataset-backup.timer >/dev/null 2>&1 || true
      echo "OTBR dataset backup timer installed but disabled because OTBR is not selected."
    fi
  fi
fi

echo "Installed and enabled LISA Edge runtime and backup services."
