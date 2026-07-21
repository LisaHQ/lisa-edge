#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WIZARD="$REPO_ROOT/install/provisioning/lisa-first-boot.sh"

output="$({
  printf '\n\n\n\n\n\n\n\n\n\n6\n'
  for _ in $(seq 1 12); do echo; done
} | bash "$WIZARD" --mode config-only --dry-run 2>&1)"

grep -qi 'Added mqtt because zigbee2mqtt depends on it' <<<"$output"
grep -q 'services: mqtt zigbee2mqtt' <<<"$output"

if conflict_output="$({
  printf '\n\n\n\n\n\n\n\n\n\n1 7\n'
  for _ in $(seq 1 6); do echo; done
  echo 1883
} | bash "$WIZARD" --mode config-only --dry-run 2>&1)"; then
  echo "Expected a selected-service port conflict to fail." >&2
  exit 1
fi
grep -q 'Port conflict' <<<"$conflict_output"

# shellcheck disable=SC1091
. "$REPO_ROOT/install/provisioning/lib/ui.sh"
if (require_bind_address TEST_BIND_ADDR 999.1.1.1) >/dev/null 2>&1; then
  echo "Expected an invalid bind address to fail." >&2
  exit 1
fi
if (require_persistent_data_path DATA_ROOT /etc/lisa-edge) >/dev/null 2>&1; then
  echo "Expected a protected persistent-data path to fail." >&2
  exit 1
fi

# --- ask_choice behavior ---
CHOICE=""
ask_choice CHOICE "Menu default" "beta" alpha beta >/dev/null <<< ""
[ "$CHOICE" = "beta" ] || { echo "ask_choice empty input must keep the default." >&2; exit 1; }
ask_choice CHOICE "Menu numeric" "alpha" alpha beta >/dev/null <<< "2"
[ "$CHOICE" = "beta" ] || { echo "ask_choice numeric input must select the option." >&2; exit 1; }
ask_choice CHOICE "Menu custom" "alpha" alpha beta >/dev/null <<< "gamma"
[ "$CHOICE" = "gamma" ] || { echo "ask_choice must accept a custom value." >&2; exit 1; }

# --- OTBR provisioning helpers (pure functions, no network) ---
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/images.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/services/otbr/provision.sh"

tags_fixture='{"results":[{"name":"latest"},{"name":"sha-69f03f0"},{"name":"v2025.12.1"},{"name":"v2026.07.0"},{"name":"main"}]}'
tag="$(printf '%s' "$tags_fixture" | otbr_latest_release_tag)"
[ "$tag" = "v2026.07.0" ] || { echo "Expected newest release tag v2026.07.0, got: $tag" >&2; exit 1; }

if printf '%s' '{"results":[{"name":"latest"},{"name":"main"},{"name":"sha-abc1234"}]}' |
  otbr_latest_release_tag | grep -q .; then
  echo "Expected no release tag from floating-only tag lists." >&2
  exit 1
fi

if ! otbr_image_is_floating "openthread/border-router:latest"; then
  echo "Expected openthread/border-router:latest to be floating." >&2
  exit 1
fi
if otbr_image_is_floating "openthread/border-router:v2026.07.0"; then
  echo "Expected a release tag to not be floating." >&2
  exit 1
fi
if otbr_image_is_floating "openthread/border-router@sha256:1111111111111111111111111111111111111111111111111111111111111111"; then
  echo "Expected a pinned digest to not be floating." >&2
  exit 1
fi
if otbr_image_is_floating "registry.local/otbr:latest"; then
  echo "Expected a custom registry image to be left untouched." >&2
  exit 1
fi

echo "Provisioning-wizard tests passed."
