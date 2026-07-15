#!/usr/bin/env bash

configure_vpn_tailscale() {
  echo
  echo "--- Tailscale wizard ---"
  ask_secret TS_AUTHKEY "Tailscale auth key" "${TS_AUTHKEY:-}"
  ask_value TS_EXTRA_ARGS "Tailscale extra arguments" "${TS_EXTRA_ARGS:-}"
  TS_USERSPACE=false
  if [ -z "$TS_AUTHKEY" ]; then
    warn "No auth key supplied. Tailscale may require interactive authentication after deploy."
  fi
}
