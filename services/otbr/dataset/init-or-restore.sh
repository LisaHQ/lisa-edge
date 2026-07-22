#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$EDGE_REPO"

set -a
source ./.env
set +a

LATEST="${OTBR_DATASET_LATEST:-/srv/lisa-edge/backups/otbr/latest.dataset.hex}"

# shellcheck disable=SC1091
. "$EDGE_REPO/lib/paths.sh"
# shellcheck disable=SC1091
. "$EDGE_REPO/services/otbr/dataset/lib.sh"
BACKUP_DIR="${OTBR_DATASET_BACKUP_DIR:-/srv/lisa-edge/backups/otbr}"
lisa_validate_persistent_path OTBR_DATASET_BACKUP_DIR "$BACKUP_DIR"
PENDING_DATASET="$BACKUP_DIR/$OTBR_PENDING_DATASET_FILE_NAME"
PENDING_NEW_NETWORK="$BACKUP_DIR/$OTBR_PENDING_NEW_NETWORK_FILE_NAME"

echo "Waiting for OTBR container..."
CONTAINER_RUNNING=0
for _ in $(seq 1 60); do
  if docker ps --format '{{.Names}}' | grep -qx lisa-otbr; then
    CONTAINER_RUNNING=1
    break
  fi
  sleep 2
done
if [ "$CONTAINER_RUNNING" -ne 1 ]; then
  echo "ERROR: lisa-otbr container is not running." >&2
  echo "Inspect next: docker ps -a --filter name=lisa-otbr; docker logs --tail 50 lisa-otbr" >&2
  exit 1
fi

# The container can be Running while otbr-agent is still starting or is
# crash-looping (for example when the RCP radio cannot be opened). ot-ctl
# reports "connect session failed" until the agent socket exists, so gate all
# dataset decisions on agent readiness instead of container state.
echo "Waiting for otbr-agent to accept commands..."
AGENT_READY=0
for _ in $(seq 1 60); do
  if docker exec lisa-otbr ot-ctl state >/dev/null 2>&1; then
    AGENT_READY=1
    break
  fi
  sleep 2
done
if [ "$AGENT_READY" -ne 1 ]; then
  {
    echo "ERROR: otbr-agent did not become ready; ot-ctl cannot connect to its socket."
    echo "The lisa-otbr container is running but the OpenThread agent has not started."
    echo "Inspect next:"
    echo "  docker logs --tail 50 lisa-otbr"
    echo "  ls -l ${THREAD_RADIO_DEVICE:-/dev/serial/by-id/}"
    echo "Common causes:"
    echo "  - THREAD_RADIO_DEVICE does not point at the attached RCP radio"
    echo "  - the radio was unplugged or re-enumerated under a new device path"
    echo "  - THREAD_RADIO_URL uses the wrong UART baud rate for this radio"
    echo "  - OTBR_BACKBONE_IF does not match an active host interface"
  } >&2
  exit 1
fi

# Classify the active dataset instead of trusting a single read. A transient
# ot-ctl failure must never be mistaken for "no dataset": with auto-create
# enabled that would replace a live Thread network and orphan its devices.
# Sets DATASET_HEX. Returns 0=present, 1=agent confirmed absent, 2=undetermined.
read_active_dataset() {
  local output=""
  DATASET_HEX=""
  if output="$(docker exec lisa-otbr ot-ctl dataset active -x 2>&1)"; then
    # ot-ctl terminates lines with CRLF; strip \r or the hex line never matches.
    DATASET_HEX="$(printf '%s\n' "$output" | tr -d '\r' | awk '/^[0-9a-fA-F]+$/ {print $1; exit}')"
    [ -n "$DATASET_HEX" ] && return 0
  fi
  if printf '%s' "$output" | grep -qi 'NotFound'; then
    return 1
  fi
  return 2
}

# Form a brand-new Thread network and store its dataset as the newest backup.
create_new_thread_network() {
  docker exec lisa-otbr ot-ctl dataset init new
  docker exec lisa-otbr ot-ctl dataset commit active
  docker exec lisa-otbr ot-ctl ifconfig up
  docker exec lisa-otbr ot-ctl thread start
  # Attaching and BBR/TREL setup can briefly destabilize the control session.
  # Confirm the committed dataset is readable before backing it up.
  local confirmed=0
  local rc
  for _ in $(seq 1 30); do
    rc=0
    read_active_dataset || rc=$?
    if [ "$rc" -eq 0 ]; then
      confirmed=1
      break
    fi
    sleep 2
  done
  if [ "$confirmed" -ne 1 ]; then
    {
      echo "ERROR: Created a new Thread network but could not read it back."
      echo "Inspect next: docker exec lisa-otbr ot-ctl state; docker exec lisa-otbr ot-ctl dataset active -x"
      echo "Then run services/otbr/dataset/backup.sh manually to store the dataset."
    } >&2
    return 1
  fi
  "$EDGE_REPO/services/otbr/dataset/backup.sh"
}

DATASET_STATUS=""
for _ in $(seq 1 30); do
  RC=0
  read_active_dataset || RC=$?
  if [ "$RC" -eq 0 ]; then
    DATASET_STATUS=present
    break
  fi
  if [ "$RC" -eq 1 ]; then
    DATASET_STATUS=absent
    break
  fi
  sleep 2
done
if [ -z "$DATASET_STATUS" ]; then
  {
    echo "ERROR: Could not determine the active Thread dataset state."
    echo "otbr-agent answered readiness checks but dataset reads kept failing."
    echo "Refusing to restore or create a network on an ambiguous state."
    echo "Inspect next:"
    echo "  docker logs --tail 50 lisa-otbr"
    echo "  docker exec lisa-otbr ot-ctl state"
    echo "  docker exec lisa-otbr ot-ctl dataset active -x"
    echo "Rerun deploy once ot-ctl answers consistently."
  } >&2
  exit 1
fi

# One-shot dataset change staged by the provisioning wizard. Applied exactly
# once: the marker is removed only after the change fully succeeds, so an
# interrupted deploy safely retries. The dataset state was classified above,
# so this never acts on an ambiguous agent.
if [ -f "$PENDING_DATASET" ] || [ -f "$PENDING_NEW_NETWORK" ]; then
  if [ "$DATASET_STATUS" = "present" ]; then
    echo "Provisioning staged a dataset change. Backing up the currently active dataset first."
    "$EDGE_REPO/services/otbr/dataset/backup.sh"
  fi
  if [ -f "$PENDING_DATASET" ]; then
    echo "Applying the Thread dataset selected during provisioning."
    "$EDGE_REPO/services/otbr/dataset/restore.sh" "$PENDING_DATASET"
    # Snapshot the now-active dataset so latest.dataset.hex reflects it.
    "$EDGE_REPO/services/otbr/dataset/backup.sh"
  else
    echo "Creating the new Thread network selected during provisioning."
    create_new_thread_network
  fi
  rm -f -- "$PENDING_DATASET" "$PENDING_NEW_NETWORK"
  exit 0
fi

if [ "$DATASET_STATUS" = "present" ]; then
  echo "OTBR already has active dataset. Backing it up."
  "$EDGE_REPO/services/otbr/dataset/backup.sh"
  exit 0
fi

if [ "${OTBR_AUTO_RESTORE_DATASET:-1}" = "1" ] && [ -f "$LATEST" ]; then
  echo "No active dataset found. Restoring latest dataset."
  "$EDGE_REPO/services/otbr/dataset/restore.sh" "$LATEST"
  exit 0
fi

if [ "${OTBR_AUTO_CREATE_NETWORK:-0}" = "1" ]; then
  echo "No dataset found. Creating a new Thread network."
  create_new_thread_network
  exit 0
fi

echo "ERROR: No active dataset and no backup found."
echo "Refusing to auto-create a new Thread network unless OTBR_AUTO_CREATE_NETWORK=1."
exit 1
