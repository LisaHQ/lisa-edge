#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

output="$({
  printf '\n\n\n\n\n\n\n\n\n\n6\n'
  for _ in $(seq 1 12); do echo; done
} | bash "$REPO_ROOT/provisioning/lisa-first-boot.sh" --mode config-only --dry-run 2>&1)"

grep -q 'Added MQTT because Zigbee2MQTT depends on it' <<<"$output"
grep -q 'services: mqtt zigbee2mqtt' <<<"$output"

if conflict_output="$({
  printf '\n\n\n\n\n\n\n\n\n\n1 7\n'
  for _ in $(seq 1 6); do echo; done
  echo 1883
} | bash "$REPO_ROOT/provisioning/lisa-first-boot.sh" --mode config-only --dry-run 2>&1)"; then
  echo "Expected a selected-service port conflict to fail." >&2
  exit 1
fi
grep -q 'Port conflict' <<<"$conflict_output"

# shellcheck disable=SC1091
. "$REPO_ROOT/provisioning/lib/ui.sh"
if (require_bind_address TEST_BIND_ADDR 999.1.1.1) >/dev/null 2>&1; then
  echo "Expected an invalid bind address to fail." >&2
  exit 1
fi
if (require_persistent_data_path DATA_ROOT /etc/lisa-edge) >/dev/null 2>&1; then
  echo "Expected a protected persistent-data path to fail." >&2
  exit 1
fi

echo "Provisioning-wizard tests passed."
