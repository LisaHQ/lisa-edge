#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/compose.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/lib/images.sh"

LISA_COMPOSE_SERVICES="mqtt"
MQTT_IMAGE="eclipse-mosquitto:2"
LISA_REQUIRE_PINNED_IMAGES=0
lisa_validate_selected_images

LISA_REQUIRE_PINNED_IMAGES=1
if lisa_validate_selected_images >/dev/null 2>&1; then
  echo "Expected floating image to fail strict pin policy." >&2
  exit 1
fi

MQTT_IMAGE="eclipse-mosquitto@sha256:$(printf 'a%.0s' {1..64})"
lisa_validate_selected_images

echo "Container-image policy tests passed."
