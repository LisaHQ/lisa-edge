#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/thread-dataset.sh"

fail() {
  echo "THREAD DATASET TEST ERROR: $*" >&2
  exit 1
}

# Synthetic dataset (never a real network key): active timestamp, channel 15,
# extended PAN 1122334455667788, channel mask, mesh-local prefix
# fd00cafe00beef00, network key, name "LISA-TST", PAN 0xabcd, security policy.
DATASET="0e080000000000010000"
DATASET+="000300000f"
DATASET+="02081122334455667788"
DATASET+="35060004001fffe0"
DATASET+="0708fd00cafe00beef00"
DATASET+="0510000102030405060708090a0b0c0d0e0f"
DATASET+="03084c4953412d545354"
DATASET+="0102abcd"
DATASET+="0c0402a0f7f8"

[ "$(thread_dataset_tlv_value "$DATASET" 02)" = "1122334455667788" ] ||
  fail "extended PAN ID TLV was not extracted"
[ "$(thread_dataset_tlv_value "${DATASET^^}" 02)" = "1122334455667788" ] ||
  fail "uppercase dataset input was not accepted"
[ "$(thread_dataset_tlv_value "$DATASET" 07)" = "fd00cafe00beef00" ] ||
  fail "mesh-local prefix TLV was not extracted"
[ "$(thread_dataset_tlv_value "$DATASET" 01)" = "abcd" ] ||
  fail "PAN ID TLV was not extracted"
[ "$(thread_dataset_channel "$DATASET")" = "15" ] ||
  fail "channel was not decoded"
[ -z "$(thread_dataset_tlv_value "$DATASET" aa)" ] ||
  fail "absent TLV type must print nothing"
[ -z "$(thread_dataset_tlv_value "0e08" 0e)" ] ||
  fail "truncated TLV stream must print nothing"
[ -z "$(thread_dataset_tlv_value "zz00" 00)" ] ||
  fail "non-hex input must print nothing"

# --- decoded identity helpers ---
[ "$(thread_dataset_network_name "$DATASET")" = "LISA-TST" ] ||
  fail "network name was not decoded"
[ "$(thread_dataset_pan_id "$DATASET")" = "0xABCD" ] ||
  fail "PAN ID was not formatted as 0xABCD"
[ "$(thread_dataset_ext_pan_id "$DATASET")" = "1122334455667788" ] ||
  fail "extended PAN ID was not extracted"
[ "$(thread_dataset_mesh_local_prefix "$DATASET")" = "fd00:cafe:00be:ef00::/64" ] ||
  fail "mesh-local prefix was not formatted as an IPv6 /64"
[ "$(thread_dataset_active_timestamp "$DATASET")" = "0000000000010000" ] ||
  fail "active timestamp was not extracted"
thread_dataset_has_network_key "$DATASET" || fail "network key presence was not detected"
if thread_dataset_has_pskc "$DATASET"; then
  fail "PSKc presence must not be reported when the TLV is absent"
fi

# 16-byte (maximum length) network name must decode fully.
MAX_NAME_DATASET="03104142434445464748494a4b4c4d4e4f50"
[ "$(thread_dataset_network_name "$MAX_NAME_DATASET")" = "ABCDEFGHIJKLMNOP" ] ||
  fail "16-byte network name was not decoded"
# 17-byte name TLV is invalid and must decode to nothing.
LONG_NAME_DATASET="03114142434445464748494a4b4c4d4e4f5051"
[ -z "$(thread_dataset_network_name "$LONG_NAME_DATASET")" ] ||
  fail "network name longer than 16 bytes must be rejected"
# Control characters inside the name must be rejected (terminal injection).
CTRL_NAME_DATASET="03044c491b53"
[ -z "$(thread_dataset_network_name "$CTRL_NAME_DATASET")" ] ||
  fail "network name with control characters must be rejected"

# --- input robustness ---
thread_dataset_is_valid_hex "$DATASET" || fail "valid dataset hex was rejected"
thread_dataset_is_valid_hex "0E08" || fail "uppercase hex must be accepted"
if thread_dataset_is_valid_hex "0e080"; then fail "odd-length hex must be rejected"; fi
if thread_dataset_is_valid_hex ""; then fail "empty dataset must be rejected"; fi
if thread_dataset_is_valid_hex "zz00"; then fail "non-hex dataset must be rejected"; fi
[ -z "$(thread_dataset_tlv_value "0e080" 0e)" ] ||
  fail "odd-length input must yield no TLV values"
# Unknown TLV types must be skipped without derailing later TLVs.
UNKNOWN_TLV_DATASET="f70299990102abcd"
[ "$(thread_dataset_tlv_value "$UNKNOWN_TLV_DATASET" 01)" = "abcd" ] ||
  fail "unknown TLVs must be skipped while parsing"

# --- redacted summary ---
SUMMARY="$(thread_dataset_summary "$DATASET")"
grep -q 'Thread network:       LISA-TST' <<<"$SUMMARY" || fail "summary must show the network name"
grep -q 'Network key:          \[REDACTED\]' <<<"$SUMMARY" || fail "summary must redact the network key"
grep -q 'PSKc:                 (not present)' <<<"$SUMMARY" || fail "summary must report an absent PSKc"
if grep -qi '000102030405060708090a0b0c0d0e0f' <<<"$SUMMARY"; then
  fail "summary must never contain the network key material"
fi
if thread_dataset_summary "zz" >/dev/null 2>&1; then
  fail "summary of invalid hex must fail"
fi

# --- configured network-name validation ---
thread_network_name_is_valid "LISA-HOME-01" || fail "valid network name was rejected"
if thread_network_name_is_valid "" 2>/dev/null; then
  fail "empty network name must be rejected"
fi
if thread_network_name_is_valid "ABCDEFGHIJKLMNOPQ" 2>/dev/null; then
  fail "17-character ASCII name must be rejected"
fi
# 9 characters but 17 bytes in UTF-8: the BYTE limit must apply.
if thread_network_name_is_valid "ééééééééa" 2>/dev/null; then
  fail "multi-byte name exceeding 16 bytes must be rejected"
fi
byte_error="$(thread_network_name_is_valid "ééééééééa" 2>&1 || true)"
grep -q 'bytes' <<<"$byte_error" || fail "byte-length rejection must mention bytes"
if thread_network_name_is_valid "$(printf 'bad\tname')" 2>/dev/null; then
  fail "control characters in the name must be rejected"
fi

LINE='2026-07-22 19:51:05.918 INFO MatterController Registered Thread credentials from stored:default (xp=1122334455667788, ch=15, panId=0xabcd, mlPrefix=FD00CAFE00BEEF00, activeTs=0000000000010000, pskc=set, networkKey=set, secPolicy=rotation672h/flags=0xF7F8, unknownTlvs=1)'

[ "$(thread_matter_credentials_field "$LINE" xp)" = "1122334455667788" ] ||
  fail "xp field was not parsed from the credentials line"
[ "$(thread_matter_credentials_field "$LINE" ch)" = "15" ] ||
  fail "ch field was not parsed from the credentials line"
[ "$(thread_matter_credentials_field "$LINE" panId)" = "0xabcd" ] ||
  fail "panId field was not parsed from the credentials line"
[ "$(thread_matter_credentials_field "$LINE" mlPrefix)" = "FD00CAFE00BEEF00" ] ||
  fail "mlPrefix field was not parsed from the credentials line"

if ! DETAILS="$(thread_dataset_drift_details "$DATASET" "$LINE")"; then
  fail "matching dataset and credentials must report no drift: $DETAILS"
fi
[ -z "$DETAILS" ] || fail "in-sync comparison must print nothing"

DRIFTED_LINE="${LINE/FD00CAFE00BEEF00/FDEF19987248B4D4}"
if DETAILS="$(thread_dataset_drift_details "$DATASET" "$DRIFTED_LINE")"; then
  fail "mesh-local prefix drift was not detected"
fi
grep -q 'mesh-local prefix' <<<"$DETAILS" ||
  fail "drift details must name the mismatching field"

DRIFTED_LINE="${LINE/ch=15/ch=21}"
DRIFTED_LINE="${DRIFTED_LINE/panId=0xabcd/panId=0x5b62}"
if DETAILS="$(thread_dataset_drift_details "$DATASET" "$DRIFTED_LINE")"; then
  fail "channel and PAN ID drift was not detected"
fi
grep -q 'channel' <<<"$DETAILS" || fail "channel drift must be reported"
grep -q 'PAN ID' <<<"$DETAILS" || fail "PAN ID drift must be reported"

echo "Thread dataset helper tests passed."
