#!/usr/bin/env bash
set -euo pipefail

# List the Thread credentials stored on the Matter server (operator entry
# point: lisa-edge matter credentials list). Shows non-secret summaries
# only: the WebSocket API never returns network keys or PSKc values.

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$EDGE_REPO"

usage() {
  cat <<'EOF'
Usage: lisa-edge matter credentials list

Show the Thread credential entries stored on the Matter server: credential
ID, network name, extended PAN ID, and whether the entry is the reserved
default. Secrets are never shown.

Options:
  -h, --help  Show this help.
EOF
}

ACTION=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    list)
      [ -z "$ACTION" ] || { echo "ERROR: unexpected argument: $1" >&2; exit 2; }
      ACTION=list
      ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "ERROR: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
if [ "$ACTION" != "list" ]; then
  echo "ERROR: matter credentials requires the 'list' subcommand." >&2
  usage >&2
  exit 2
fi

if [ ! -f .env ]; then
  echo "ERROR: missing .env; run 'sudo ./lisa-edge configure' (or setup) first." >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
source ./.env
set +a

# shellcheck disable=SC1091
. "$EDGE_REPO/services/matter-server/lib/ws.sh"

if ! matter_ws_container_running; then
  echo "ERROR: lisa-matter container is not running." >&2
  echo "Start it with: sudo ./lisa-edge deploy" >&2
  exit 1
fi

RC=0
OUTPUT="$(matter_ws_run credentials)" || RC=$?
if [ "$RC" -ne 0 ]; then
  echo "ERROR: could not read credentials from the Matter server (exit $RC)." >&2
  echo "Inspect next: sudo ./lisa-edge matter status; docker logs --tail 30 lisa-matter" >&2
  exit 1
fi

CONFIGURED_ID="${MATTER_THREAD_CREDENTIAL_ID:-lisa-home-01}"
COUNT="$(matter_ws_field "$OUTPUT" thread_credential_count)"
if [ "${COUNT:-0}" = "0" ]; then
  echo "No Thread credentials are stored on the Matter server."
  echo "Store one with: sudo ./lisa-edge matter thread sync"
  exit 0
fi

printf '%-24s %-18s %-18s %s\n' "ID" "NETWORK NAME" "EXTENDED PAN ID" "DEFAULT"
while IFS=$'\t' read -r id name xpan; do
  default_marker="-"
  [ "$id" = "default" ] && default_marker="reserved default"
  [ "$id" = "$CONFIGURED_ID" ] && default_marker="configured (MATTER_THREAD_CREDENTIAL_ID)"
  printf '%-24s %-18s %-18s %s\n' "$id" "${name:--}" "${xpan:--}" "$default_marker"
done < <(matter_ws_thread_entries "$OUTPUT")
