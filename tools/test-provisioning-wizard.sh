#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

output="$({
  printf '\n\n\n\n\n\n6\n'
  for _ in $(seq 1 12); do echo; done
} | bash "$REPO_ROOT/provisioning/lisa-first-boot.sh" --mode config-only --dry-run 2>&1)"

grep -q 'Added MQTT because Zigbee2MQTT depends on it' <<<"$output"
grep -q 'services: mqtt zigbee2mqtt' <<<"$output"

echo "Provisioning-wizard tests passed."
