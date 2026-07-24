#!/usr/bin/env bash
set -euo pipefail

# OTBR CLI behavior: help hierarchy, argument validation, exit codes,
# secret redaction on the default output, explicit secret output, and
# protected dataset export. Docker is mocked through a PATH shim.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

fail() {
  echo "OTBR CLI TEST ERROR: $*" >&2
  exit 1
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/otbr-cli-test.XXXXXX")"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# Synthetic dataset (never a real key): includes network key TLV 0510...
MOCK_DATASET="0e080000000000010000000300000f0208112233445566778835060004001fffe00708fd00cafe00beef000510000102030405060708090a0b0c0d0e0f03084c4953412d545354  0102abcd0c0402a0f7f8"
MOCK_DATASET="${MOCK_DATASET// /}"
KEY_MATERIAL="000102030405060708090a0b0c0d0e0f"

mkdir -p "$WORK_DIR/bin"
cat > "$WORK_DIR/bin/docker" <<EOF
#!/usr/bin/env bash
# Docker shim for OTBR CLI tests.
case "\$*" in
  "ps --format {{.Names}}") printf 'lisa-otbr\n' ;;
  *"ot-ctl dataset active -x"*) printf '%s\r\nDone\r\n' "$MOCK_DATASET" ;;
  *"ot-ctl state"*) printf 'leader\r\nDone\r\n' ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$WORK_DIR/bin/docker"
export PATH="$WORK_DIR/bin:$PATH"

CLI="$REPO_ROOT/lisa-edge"

# --- help hierarchy -----------------------------------------------------
bash "$CLI" help | grep -q 'otbr dataset show' || fail "root help must advertise otbr dataset show"
bash "$CLI" help | grep -q 'matter thread sync' || fail "root help must advertise matter thread sync"
bash "$CLI" help | grep -q 'doctor matter-thread' || fail "root help must advertise doctor matter-thread"
for args in "otbr status -h" "otbr dataset show --help" "otbr dataset export -h" \
  "otbr dataset backup -h" "otbr dataset restore -h" "otbr network create -h" \
  "matter status -h" "matter credentials -h" "matter thread --help" \
  "matter reset -h" "doctor matter-thread -h" "health --help"; do
  # shellcheck disable=SC2086
  bash "$CLI" $args >/dev/null || fail "help must exit 0 for: lisa-edge $args"
done

# --- unknown subcommands are rejected by the dispatcher ------------------
for args in "otbr bogus" "otbr dataset bogus" "otbr network bogus" \
  "matter bogus" "doctor bogus"; do
  # shellcheck disable=SC2086
  if bash "$CLI" $args >/dev/null 2>&1; then
    fail "dispatcher must reject: lisa-edge $args"
  fi
done

# --- otbr dataset show: redacted by default ------------------------------
show_output="$(bash "$CLI" otbr dataset show)"
grep -q 'Thread network:       LISA-TST' <<<"$show_output" || fail "show must decode the network name"
grep -q '\[REDACTED\]' <<<"$show_output" || fail "show must redact secrets"
if grep -qi "$KEY_MATERIAL" <<<"$show_output"; then
  fail "default show output must never contain key material"
fi
if grep -qi "$MOCK_DATASET" <<<"$show_output"; then
  fail "default show output must never contain the raw dataset"
fi

# --- otbr dataset show --show-secret ------------------------------------
secret_stdout="$(bash "$CLI" otbr dataset show --show-secret 2>"$WORK_DIR/secret.stderr")"
[ "$secret_stdout" = "$MOCK_DATASET" ] || fail "--show-secret must print the exact dataset on stdout"
grep -qi 'WARNING' "$WORK_DIR/secret.stderr" || fail "--show-secret must print a warning"

# --- argument validation never leaks the dataset --------------------------
rc=0
bad_output="$(bash "$CLI" otbr dataset show --bogus 2>&1)" || rc=$?
[ "$rc" -eq 2 ] || fail "unknown option must exit 2, got $rc"
if grep -qi "$KEY_MATERIAL" <<<"$bad_output"; then
  fail "argument errors must never leak the dataset"
fi
rc=0
bash "$CLI" otbr dataset show unexpected-positional >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "unexpected positional must exit 2, got $rc"
rc=0
bash "$CLI" otbr dataset show --show-secret extra >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "--show-secret with extra positional must exit 2 (validate before print), got $rc"

# --- otbr dataset export ---------------------------------------------------
EXPORT_FILE="$WORK_DIR/exported.hex"
export_output="$(bash "$CLI" otbr dataset export --output "$EXPORT_FILE")"
[ -f "$EXPORT_FILE" ] || fail "export must create the output file"
[ "$(stat -c %a "$EXPORT_FILE")" = "600" ] || fail "export file must be mode 0600"
[ "$(cat "$EXPORT_FILE")" = "$MOCK_DATASET" ] || fail "export file content mismatch"
if grep -qi "$KEY_MATERIAL" <<<"$export_output"; then
  fail "export output must never print the dataset"
fi
grep -qi 'WARNING' <<<"$export_output" || fail "export must warn about credential content"

rc=0
bash "$CLI" otbr dataset export --output "$EXPORT_FILE" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "export must refuse to overwrite an existing file, got $rc"
rc=0
bash "$CLI" otbr dataset export --output "$WORK_DIR" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "export must refuse a directory target, got $rc"
rc=0
bash "$CLI" otbr dataset export --output "$WORK_DIR/../escape.hex" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "export must refuse traversal paths, got $rc"
rc=0
bash "$CLI" otbr dataset export >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "export without --output must exit 2, got $rc"
rc=0
bash "$CLI" otbr dataset export --output "$WORK_DIR/missing-dir/out.hex" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "export into a missing parent directory must exit 2, got $rc"

# --- otbr dataset backup argument validation ------------------------------
rc=0
bash "$CLI" otbr dataset backup --bogus >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "backup must reject unknown options, got $rc"
rc=0
bash "$CLI" otbr dataset backup positional >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "backup must reject positional labels (use --label), got $rc"
rc=0
bash "$CLI" otbr dataset restore one two >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "restore must reject extra positionals, got $rc"
rc=0
bash "$CLI" otbr network create extra >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "network create must reject positionals, got $rc"

echo "OTBR CLI tests passed."
