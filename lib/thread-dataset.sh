#!/usr/bin/env bash

# Shared helpers for the Thread operational dataset: parse dataset TLVs,
# read both sides of the OTBR <-> Matter server credential pair, and report
# drift between them. OTBR's active dataset is authoritative; the Matter
# server hands its stored copy to devices during commissioning, so a stale
# copy makes every new Thread commissioning fail at the operative
# reconnection step while already-commissioned devices keep working.
#
# Sourced by ops/deploy/healthcheck.sh, services/otbr/dataset/show.sh,
# services/matter-server/data/sync-thread-dataset.sh and unit tests. The
# thread_dataset_* and thread_matter_credentials_field helpers are pure (no
# docker, no side effects) so tests can cover them; only the *_live helpers
# touch docker. Keep this file free of side effects.

# Print the value (hex) of the first TLV with the requested type from a
# Thread operational dataset hex string. Args: dataset_hex tlv_type (two hex
# chars, e.g. 02 for extended PAN ID). Prints nothing when the input is
# malformed or the type is absent.
thread_dataset_tlv_value() {
  local hex="${1,,}" want="${2,,}"
  local i=0 len type value_len
  [[ "$hex" =~ ^[0-9a-f]*$ ]] || return 0
  len=${#hex}
  while [ $((i + 4)) -le "$len" ]; do
    type="${hex:i:2}"
    value_len=$((16#${hex:i+2:2}))
    i=$((i + 4))
    [ $((i + value_len * 2)) -le "$len" ] || return 0
    if [ "$type" = "$want" ]; then
      printf '%s\n' "${hex:i:value_len * 2}"
      return 0
    fi
    i=$((i + value_len * 2))
  done
  return 0
}

# Print the channel number (decimal) from a dataset hex string. The channel
# TLV (type 0x00) value is one channel-page byte followed by a 16-bit
# big-endian channel number.
thread_dataset_channel() {
  local value
  value="$(thread_dataset_tlv_value "$1" 00)"
  [ "${#value}" -eq 6 ] || return 0
  printf '%d\n' "$((16#${value:2:4}))"
}

# Print one field from the Matter server's "Registered Thread credentials"
# startup log line. Example: thread_matter_credentials_field "$line" panId
# prints 0x5b62.
thread_matter_credentials_field() {
  local line="$1" field="$2"
  printf '%s\n' "$line" |
    grep -oE "${field}=[^,)]+" | head -n 1 | cut -d= -f2-
}

# Compare an OTBR dataset hex string against the Matter server's registered
# credentials line. Prints one line per mismatching field; returns 0 when
# every comparable field matches, 1 otherwise. A field absent on either side
# is skipped: absence is not proof of drift, and the network key is redacted
# in the log line so it can never be compared.
thread_dataset_drift_details() {
  local hex="$1" line="$2" drift=0
  local otbr_value matter_value

  otbr_value="$(thread_dataset_tlv_value "$hex" 02)"
  otbr_value="${otbr_value^^}"
  matter_value="$(thread_matter_credentials_field "$line" xp)"
  matter_value="${matter_value^^}"
  if [ -n "$otbr_value" ] && [ -n "$matter_value" ] &&
    [ "$otbr_value" != "$matter_value" ]; then
    echo "extended PAN ID: OTBR=$otbr_value matter=$matter_value"
    drift=1
  fi

  otbr_value="$(thread_dataset_channel "$hex")"
  matter_value="$(thread_matter_credentials_field "$line" ch)"
  if [ -n "$otbr_value" ] && [ -n "$matter_value" ] &&
    [ "$otbr_value" != "$matter_value" ]; then
    echo "channel: OTBR=$otbr_value matter=$matter_value"
    drift=1
  fi

  otbr_value="$(thread_dataset_tlv_value "$hex" 01)"
  otbr_value="${otbr_value^^}"
  matter_value="$(thread_matter_credentials_field "$line" panId)"
  matter_value="${matter_value^^}"
  matter_value="${matter_value#0X}"
  if [ -n "$otbr_value" ] && [ -n "$matter_value" ] &&
    [ "$otbr_value" != "$matter_value" ]; then
    echo "PAN ID: OTBR=0x$otbr_value matter=0x$matter_value"
    drift=1
  fi

  otbr_value="$(thread_dataset_tlv_value "$hex" 07)"
  otbr_value="${otbr_value^^}"
  matter_value="$(thread_matter_credentials_field "$line" mlPrefix)"
  matter_value="${matter_value^^}"
  if [ -n "$otbr_value" ] && [ -n "$matter_value" ] &&
    [ "$otbr_value" != "$matter_value" ]; then
    echo "mesh-local prefix: OTBR=$otbr_value matter=$matter_value"
    drift=1
  fi

  return "$drift"
}

# --- live helpers (require docker and running containers) -------------------

# Print OTBR's active operational dataset as one hex line, or nothing when
# OTBR is not running, otbr-agent is not ready, or no dataset is active.
thread_otbr_active_dataset_hex_live() {
  docker exec lisa-otbr ot-ctl dataset active -x 2>/dev/null |
    tr -d '\r' | grep -m 1 -E '^[0-9A-Fa-f]+$' || true
}

# Print the newest "Registered Thread credentials" line from the Matter
# server logs (emitted at each container start), or nothing when the server
# has no Thread credentials or is not running.
thread_matter_registered_line_live() {
  docker logs lisa-matter 2>&1 |
    grep -F 'Registered Thread credentials' | tail -n 1 || true
}

# Report OTBR <-> Matter server Thread dataset drift. Prints a human-readable
# report; returns 0 when in sync, 1 on drift or when either side cannot be
# read.
thread_dataset_drift_report_live() {
  local hex line details
  hex="$(thread_otbr_active_dataset_hex_live)"
  if [ -z "$hex" ]; then
    echo "cannot read OTBR's active dataset (container not running, agent not ready, or no active dataset)"
    return 1
  fi
  line="$(thread_matter_registered_line_live)"
  if [ -z "$line" ]; then
    echo "the Matter server has no Thread credentials registered; run: sudo ./lisa-edge matter sync-dataset"
    return 1
  fi
  if details="$(thread_dataset_drift_details "$hex" "$line")"; then
    echo "Thread dataset is in sync between OTBR and the Matter server."
    return 0
  fi
  printf 'Thread dataset DRIFT between OTBR and the Matter server:\n%s\n' "$details"
  return 1
}
