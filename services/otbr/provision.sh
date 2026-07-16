#!/usr/bin/env bash

configure_otbr() {
  local answer
  echo
  echo "--- OpenThread Border Router wizard ---"
  ask_value THREAD_RADIO_DEVICE "Thread RCP device (/dev/serial/by-id/...)" "${THREAD_RADIO_DEVICE:-/dev/serial/by-id/YOUR_THREAD_RCP_RADIO}"
  ask_value OTBR_BACKBONE_IF "OTBR backbone network interface" "${OTBR_BACKBONE_IF:-enp1s0}"
  ask_value OTBR_THREAD_IF "Thread interface name" "${OTBR_THREAD_IF:-wpan0}"
  ask_value OTBR_LOG_LEVEL "OTBR log level" "${OTBR_LOG_LEVEL:-5}"
  ask_value OTBR_DATASET_BACKUP_DIR "Thread dataset backup directory" "${OTBR_DATASET_BACKUP_DIR:-$DATA_ROOT/backups/otbr}"
  require_persistent_data_path "OTBR_DATASET_BACKUP_DIR" "$OTBR_DATASET_BACKUP_DIR"
  # Looks unused here, but lisa-first-boot.sh writes it into .env via env_line().
  # shellcheck disable=SC2034
  OTBR_DATASET_LATEST="$OTBR_DATASET_BACKUP_DIR/latest.dataset.hex"
  ask_yes_no answer "Automatically restore the latest Thread dataset" "yes"
  # OTBR_AUTO_RESTORE_DATASET looks unused here, but lisa-first-boot.sh writes it into .env via env_line().
    # shellcheck disable=SC2034
    [ "$answer" = "yes" ] && OTBR_AUTO_RESTORE_DATASET=1 || OTBR_AUTO_RESTORE_DATASET=0
  ask_yes_no answer "Allow creating a new Thread network when no backup exists" "no"
  # OTBR_AUTO_CREATE_NETWORK looks unused here, but lisa-first-boot.sh writes it into .env via env_line().
  # shellcheck disable=SC2034
  [ "$answer" = "yes" ] && OTBR_AUTO_CREATE_NETWORK=1 || OTBR_AUTO_CREATE_NETWORK=0
  # Consumed by install/bootstrap/phases/40-core-service-prep.sh and written to .env.
  # shellcheck disable=SC2034
  LISA_ENABLE_THREAD_HOST_PREP=1
}
