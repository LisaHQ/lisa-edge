#!/usr/bin/env bash

# Shared helpers for the Thread operational dataset: parse dataset TLVs,
# read both sides of the OTBR <-> Matter server credential pair, and report
# drift between them. OTBR's active dataset is authoritative; the Matter
# server hands its stored copy to devices during commissioning, so a stale
# copy makes every new Thread commissioning fail at the operative
# reconnection step while already-commissioned devices keep working.
#
# Sourced by ops/deploy/healthcheck.sh, the OTBR/Matter CLI scripts,
# ops/diagnostics/doctor-matter-thread.sh and unit tests. The
# thread_dataset_* and thread_matter_credentials_field helpers are pure (no
# docker, no side effects) so tests can cover them; only the *_live helpers
# touch docker. Keep this file free of side effects.

# Thread operational dataset TLV types (Thread spec, MeshCoP TLVs).
# shellcheck disable=SC2034
THREAD_TLV_CHANNEL=00
THREAD_TLV_PAN_ID=01
THREAD_TLV_EXT_PAN_ID=02
THREAD_TLV_NETWORK_NAME=03
THREAD_TLV_PSKC=04
THREAD_TLV_NETWORK_KEY=05
THREAD_TLV_MESH_LOCAL_PREFIX=07
THREAD_TLV_ACTIVE_TIMESTAMP=0e

# Maximum Thread network name length in BYTES (OpenThread limit). Multi-byte
# UTF-8 names can therefore hold fewer characters than 16.
THREAD_NETWORK_NAME_MAX_BYTES=16

# True when the argument is a plausible dataset hex string: non-empty, hex
# characters only, even length (TLVs are whole bytes).
thread_dataset_is_valid_hex() {
  local hex="${1-}"
  [ -n "$hex" ] || return 1
  [[ "$hex" =~ ^[0-9a-fA-F]+$ ]] || return 1
  [ $((${#hex} % 2)) -eq 0 ]
}

# Print the value (hex) of the first TLV with the requested type from a
# Thread operational dataset hex string. Args: dataset_hex tlv_type (two hex
# chars, e.g. 02 for extended PAN ID). Prints nothing when the input is
# malformed (non-hex, odd length, truncated TLVs) or the type is absent.
thread_dataset_tlv_value() {
  local hex="${1,,}" want="${2,,}"
  local i=0 len type value_len
  [[ "$hex" =~ ^[0-9a-f]*$ ]] || return 0
  [ $((${#hex} % 2)) -eq 0 ] || return 0
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

# Decode the network name TLV (type 03) into printable text. Prints nothing
# when the TLV is absent, empty, longer than 16 bytes, or contains control
# characters (a corrupt or hostile dataset must never inject terminal codes).
thread_dataset_network_name() {
  local value byte i decoded=""
  value="$(thread_dataset_tlv_value "$1" "$THREAD_TLV_NETWORK_NAME")"
  [ -n "$value" ] || return 0
  [ $((${#value} / 2)) -le "$THREAD_NETWORK_NAME_MAX_BYTES" ] || return 0
  for ((i = 0; i < ${#value}; i += 2)); do
    byte=$((16#${value:i:2}))
    # Reject ASCII control characters and DEL; allow >=0x80 (UTF-8 bytes).
    if [ "$byte" -lt 32 ] || [ "$byte" -eq 127 ]; then
      return 0
    fi
    decoded+="$(printf "\\x${value:i:2}")"
  done
  printf '%s\n' "$decoded"
}

# Print the PAN ID as 0xABCD (uppercase), or nothing when absent/malformed.
thread_dataset_pan_id() {
  local value
  value="$(thread_dataset_tlv_value "$1" "$THREAD_TLV_PAN_ID")"
  [ "${#value}" -eq 4 ] || return 0
  printf '0x%s\n' "${value^^}"
}

# Print the extended PAN ID as 16 uppercase hex chars, or nothing.
thread_dataset_ext_pan_id() {
  local value
  value="$(thread_dataset_tlv_value "$1" "$THREAD_TLV_EXT_PAN_ID")"
  [ "${#value}" -eq 16 ] || return 0
  printf '%s\n' "${value^^}"
}

# Print the mesh-local prefix as an IPv6 /64 (e.g. fd00:cafe:be:ef00::/64),
# or nothing when absent/malformed.
thread_dataset_mesh_local_prefix() {
  local value groups
  value="$(thread_dataset_tlv_value "$1" "$THREAD_TLV_MESH_LOCAL_PREFIX")"
  [ "${#value}" -eq 16 ] || return 0
  groups="${value:0:4}:${value:4:4}:${value:8:4}:${value:12:4}"
  printf '%s::/64\n' "${groups,,}"
}

# Print the raw active timestamp TLV value (hex), or nothing when absent.
thread_dataset_active_timestamp() {
  local value
  value="$(thread_dataset_tlv_value "$1" "$THREAD_TLV_ACTIVE_TIMESTAMP")"
  [ -n "$value" ] || return 0
  printf '%s\n' "${value,,}"
}

# True when the dataset carries a network key TLV. Never prints the key.
thread_dataset_has_network_key() {
  [ -n "$(thread_dataset_tlv_value "$1" "$THREAD_TLV_NETWORK_KEY")" ]
}

# True when the dataset carries a PSKc TLV. Never prints the PSKc.
thread_dataset_has_pskc() {
  [ -n "$(thread_dataset_tlv_value "$1" "$THREAD_TLV_PSKC")" ]
}

# Print a redacted, decoded summary of a dataset hex string. Secrets are
# reported by presence only; this output is safe for logs and status.
thread_dataset_summary() {
  local hex="$1"
  local name channel pan_id ext_pan_id ml_prefix active_ts key pskc

  if ! thread_dataset_is_valid_hex "$hex"; then
    echo "Dataset is not a valid hex TLV string."
    return 1
  fi
  name="$(thread_dataset_network_name "$hex")"
  channel="$(thread_dataset_channel "$hex")"
  pan_id="$(thread_dataset_pan_id "$hex")"
  ext_pan_id="$(thread_dataset_ext_pan_id "$hex")"
  ml_prefix="$(thread_dataset_mesh_local_prefix "$hex")"
  active_ts="$(thread_dataset_active_timestamp "$hex")"
  key="(not present)"
  thread_dataset_has_network_key "$hex" && key="[REDACTED]"
  pskc="(not present)"
  thread_dataset_has_pskc "$hex" && pskc="[REDACTED]"

  printf 'Thread network:       %s\n' "${name:-(not present)}"
  printf 'Channel:              %s\n' "${channel:-(not present)}"
  printf 'PAN ID:               %s\n' "${pan_id:-(not present)}"
  printf 'Extended PAN ID:      %s\n' "${ext_pan_id:-(not present)}"
  printf 'Mesh-local prefix:    %s\n' "${ml_prefix:-(not present)}"
  printf 'Active timestamp:     %s\n' "${active_ts:-(not present)}"
  printf 'Network key:          %s\n' "$key"
  printf 'PSKc:                 %s\n' "$pskc"
}

# Validate a configured Thread network name (THREAD_NETWORK_NAME). Errors go
# to stderr. OpenThread enforces a BYTE limit, so multi-byte characters count
# more than once; the message distinguishes bytes from characters.
thread_network_name_is_valid() {
  local name="${1-}"
  local byte_length

  if [ -z "$name" ]; then
    echo "Thread network name must not be empty." >&2
    return 1
  fi
  byte_length="$(printf '%s' "$name" | LC_ALL=C wc -c)"
  if [ "$byte_length" -gt "$THREAD_NETWORK_NAME_MAX_BYTES" ]; then
    echo "Thread network name exceeds $THREAD_NETWORK_NAME_MAX_BYTES bytes:" \
      "'$name' is ${#name} character(s) but $byte_length bytes." >&2
    return 1
  fi
  if [ "$(printf '%s' "$name" | LC_ALL=C tr -d '[:cntrl:]' | LC_ALL=C wc -c)" -ne "$byte_length" ]; then
    echo "Thread network name must not contain control characters." >&2
    return 1
  fi
  return 0
}

# SUPPLEMENTAL diagnostics only: the structured WebSocket API
# (get_all_credentials) is the primary verification path, but the server's
# startup log line additionally carries channel, PAN ID, and mesh-local
# prefix, which the API does not return. Log parsing is best-effort.
#
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
    echo "the Matter server log reports no registered Thread credentials; run: sudo ./lisa-edge matter thread sync"
    return 1
  fi
  if details="$(thread_dataset_drift_details "$hex" "$line")"; then
    echo "Thread dataset is in sync between OTBR and the Matter server."
    return 0
  fi
  printf 'Thread dataset DRIFT between OTBR and the Matter server:\n%s\n' "$details"
  return 1
}
