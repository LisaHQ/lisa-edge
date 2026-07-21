#!/usr/bin/env bash

configure_matter() {
  echo
  echo "--- Matter Server wizard ---"
  info "Matter Server uses host networking (mDNS commissioning) and stores its fabric data under DATA_ROOT."
  info "The WebSocket API has no authentication; restrict TCP ${MATTER_SERVER_PORT:-5580} to trusted controller networks."
  ask_value MATTER_SERVER_PORT "Matter Server WebSocket port (healthcheck only)" "${MATTER_SERVER_PORT:-5580}"
  require_port MATTER_SERVER_PORT "$MATTER_SERVER_PORT"
}
