#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$EDGE_REPO"

set -a
source ./.env
set +a

LATEST="${OTBR_DATASET_LATEST:-/srv/lisa-edge/backups/otbr/latest.dataset.hex}"

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

CURRENT="$(docker exec lisa-otbr ot-ctl dataset active -x 2>/dev/null | awk '/^[0-9a-fA-F]+$/ {print $1; exit}' || true)"

if [ -n "$CURRENT" ]; then
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
  docker exec lisa-otbr ot-ctl dataset init new
  docker exec lisa-otbr ot-ctl dataset commit active
  docker exec lisa-otbr ot-ctl ifconfig up
  docker exec lisa-otbr ot-ctl thread start
  sleep 8
  "$EDGE_REPO/services/otbr/dataset/backup.sh"
  exit 0
fi

echo "ERROR: No active dataset and no backup found."
echo "Refusing to auto-create a new Thread network unless OTBR_AUTO_CREATE_NETWORK=1."
exit 1
