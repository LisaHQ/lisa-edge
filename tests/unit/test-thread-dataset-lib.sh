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
