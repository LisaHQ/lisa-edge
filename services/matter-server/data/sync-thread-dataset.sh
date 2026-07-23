#!/usr/bin/env bash
set -euo pipefail

# Push a Thread operational dataset into the Matter server so commissioning
# hands new devices the credentials of the live OTBR network (operator entry
# point: lisa-edge matter sync-dataset). Defaults to OTBR's current active
# dataset; an explicit dataset hex can be passed as the only argument. The
# server is restarted afterwards so it re-registers the credentials at
# startup, which is also what makes the change verifiable.
#
# Usage: lisa-edge matter sync-dataset [dataset-hex]

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$EDGE_REPO"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

case "${1:-}" in
  -h|--help)
    echo "Usage: lisa-edge matter sync-dataset [dataset-hex]"
    echo "Pushes OTBR's active Thread dataset (or the given hex) into the"
    echo "Matter server and restarts it to re-register the credentials."
    exit 0
    ;;
esac

[ -f .env ] || die "missing .env; run 'sudo ./lisa-edge configure' (or setup) first"
set -a
# shellcheck disable=SC1091
. ./.env
set +a

# shellcheck disable=SC1091
. "$EDGE_REPO/lib/thread-dataset.sh"

MATTER_PORT="${MATTER_SERVER_PORT:-5580}"

docker ps --format '{{.Names}}' 2>/dev/null | grep -qx lisa-matter ||
  die "lisa-matter container is not running; start it with: sudo ./lisa-edge deploy"

DATASET_HEX="${1:-}"
if [ -z "$DATASET_HEX" ]; then
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qx lisa-otbr ||
    die "lisa-otbr container is not running and no dataset hex was given"
  DATASET_HEX="$(thread_otbr_active_dataset_hex_live)"
  [ -n "$DATASET_HEX" ] ||
    die "OTBR has no readable active dataset (agent still starting, or no network formed)"
fi

[[ "$DATASET_HEX" =~ ^[0-9A-Fa-f]+$ ]] || die "dataset is not a hex string"
[ $((${#DATASET_HEX} % 2)) -eq 0 ] || die "dataset hex has an odd length"

echo "Setting the Thread dataset on the Matter server (WebSocket API)..."
RESULT="$(docker exec -e LISA_SYNC_PORT="$MATTER_PORT" lisa-matter node -e '
const WebSocket = require("/app/node_modules/ws");
const dataset = process.argv[1];
const ws = new WebSocket("ws://127.0.0.1:" + process.env.LISA_SYNC_PORT + "/ws");
let done = false;
const finish = (code, message) => {
  if (done) return;
  done = true;
  console.log(message);
  process.exit(code);
};
setTimeout(() => finish(1, "timeout waiting for the server response"), 15000);
ws.on("open", () => ws.send(JSON.stringify({
  message_id: "lisa-sync-dataset",
  command: "set_thread_dataset",
  args: { dataset },
})));
ws.on("message", (raw) => {
  let msg;
  try { msg = JSON.parse(raw); } catch { return; }
  if (msg.message_id !== "lisa-sync-dataset") return;
  if (msg.error_code !== undefined) {
    finish(1, "server rejected the dataset: " + (msg.details || msg.error_code));
  } else {
    finish(0, "accepted");
  }
});
ws.on("error", (err) => finish(1, "websocket error: " + err.message));
' "$DATASET_HEX")" || die "$RESULT"
echo "Server response: $RESULT"

echo "Restarting lisa-matter so the credentials are re-registered..."
docker restart lisa-matter >/dev/null

for _ in $(seq 1 30); do
  if timeout 3 bash -c "</dev/tcp/127.0.0.1/${MATTER_PORT}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "Verifying..."
if REPORT="$(thread_dataset_drift_report_live)"; then
  echo "$REPORT"
else
  echo "WARNING: $REPORT" >&2
  echo "The server may still be starting; re-check with: sudo ./lisa-edge health" >&2
  exit 1
fi
