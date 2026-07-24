#!/usr/bin/env bash
set -euo pipefail

# Matter WebSocket client behavior against a scripted mock of the `ws`
# module: server_info handling, schema validation, named set_thread_dataset,
# get_all_credentials verification, API rejection, timeout, disconnect,
# unrelated events, credential mismatch, and secret redaction. Runs the real
# ws-client.js under node; no network and no docker are involved.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLIENT="$REPO_ROOT/services/matter-server/lib/ws-client.js"

fail() {
  echo "MATTER WS CLIENT TEST ERROR: $*" >&2
  exit 1
}

command -v node >/dev/null 2>&1 || fail "node is required for the Matter WebSocket client tests"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matter-ws-test.XXXXXX")"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

mkdir -p "$WORK_DIR/node_modules/ws"
cat > "$WORK_DIR/node_modules/ws/index.js" <<'EOF'
// Scripted mock of the `ws` module for ws-client.js tests. The scenario is
// selected via MOCK_SCENARIO.
const { EventEmitter } = require("events");
class WebSocket extends EventEmitter {
  constructor(url) {
    super();
    this.url = url;
    const scenario = process.env.MOCK_SCENARIO || "ok";
    setImmediate(() => {
      if (scenario === "connect-fail") { this.emit("error", new Error("ECONNREFUSED")); return; }
      this.emit("open");
      if (scenario === "no-server-info") return;
      // An unrelated event BEFORE server info must be ignored.
      this.emit("message", JSON.stringify({ event: "node_updated", data: {} }));
      this.emit("message", "this is not json");
      const schema = scenario === "old-schema" ? 11 : 12;
      this.emit("message", JSON.stringify({
        schema_version: schema, min_supported_schema_version: 11,
        sdk_version: "0.17.5", wifi_credentials_set: false,
        thread_credentials_set: true, bluetooth_enabled: true,
      }));
    });
  }
  send(raw) {
    const msg = JSON.parse(raw);
    const scenario = process.env.MOCK_SCENARIO || "ok";
    setImmediate(() => {
      // Unrelated event and a foreign response interleaved with every call.
      this.emit("message", JSON.stringify({ event: "attribute_updated", data: {} }));
      this.emit("message", JSON.stringify({ message_id: "someone-else", result: null }));
      if (msg.command === "set_thread_dataset") {
        if (typeof msg.args.dataset !== "string" || !msg.args.id) {
          this.emit("message", JSON.stringify({ message_id: msg.message_id, error_code: 1, details: "missing args" }));
          return;
        }
        if (scenario === "reject") {
          this.emit("message", JSON.stringify({
            message_id: msg.message_id, error_code: 9,
            details: "invalid dataset 0e080000000000010000000300000f0208112233445566778835060004001fffe0",
          }));
          return;
        }
        if (scenario === "disconnect") { this.emit("close"); return; }
        if (scenario === "timeout") return;
        this.emit("message", JSON.stringify({ message_id: msg.message_id, result: null }));
      } else if (msg.command === "get_all_credentials") {
        const entries = scenario === "missing-entry" ? []
          : scenario === "mismatch"
            ? [{ id: "lisa-home-01", networkName: "OTHER-NET", extPanId: "9999999999999999" }]
            : [{ id: "lisa-home-01", networkName: "LISA-HOME-01", extPanId: "1122334455667788" },
               { id: "default", networkName: "OldNet", extPanId: "8877665544332211" }];
        this.emit("message", JSON.stringify({ message_id: msg.message_id, result: { wifi: [], thread: entries } }));
      } else if (msg.command === "get_fabric_label") {
        this.emit("message", JSON.stringify({ message_id: msg.message_id, result: { fabric_label: "LISA Home" } }));
      } else if (msg.command === "get_nodes") {
        this.emit("message", JSON.stringify({ message_id: msg.message_id, result: [{}, {}] }));
      } else if (msg.command === "remove_thread_dataset") {
        this.emit("message", JSON.stringify({ message_id: msg.message_id, result: null }));
      }
    });
  }
  close() {}
}
module.exports = WebSocket;
module.exports.WebSocket = WebSocket;
EOF

DATASET="0e080000000000010000000300000f0208112233445566778835060004001fffe00510000102030405060708090a0b0c0d0e0f03084c4953412d545354"

run_client() {
  local scenario="$1" command="$2" credential="${3:-}" dataset="${4:-}"
  NODE_PATH="$WORK_DIR/node_modules" MOCK_SCENARIO="$scenario" \
    MWS_COMMAND="$command" MWS_CREDENTIAL_ID="$credential" MWS_DATASET="$dataset" \
    MWS_CONNECT_TIMEOUT_MS=400 MWS_RESPONSE_TIMEOUT_MS=400 \
    node "$CLIENT" 2>&1
}

# --- successful named sync ---------------------------------------------------
output="$(run_client ok sync lisa-home-01 "$DATASET")" || fail "sync must succeed: $output"
grep -q '^server.schema_version=12$' <<<"$output" || fail "server info must be printed"
grep -q '^stored.id=lisa-home-01$' <<<"$output" || fail "stored credential id must be verified"
grep -q '^stored.network_name=LISA-HOME-01$' <<<"$output" || fail "stored network name must be printed"
grep -q '^sync.result=ok$' <<<"$output" || fail "sync must report ok"
if grep -qi "$DATASET" <<<"$output"; then
  fail "the dataset must never appear in client output"
fi

# --- API rejection: exit 4, details redacted ---------------------------------
rc=0
output="$(run_client reject sync lisa-home-01 "$DATASET")" || rc=$?
[ "$rc" -eq 4 ] || fail "server rejection must exit 4, got $rc"
grep -q 'REDACTED' <<<"$output" || fail "long hex in server details must be redacted"
if grep -qi '112233445566778835060004' <<<"$output"; then
  fail "server-provided dataset material must be redacted"
fi

# --- unsupported schema: exit 6 ----------------------------------------------
rc=0
output="$(run_client old-schema server-info)" || rc=$?
[ "$rc" -eq 6 ] || fail "old schema must exit 6, got $rc"
grep -q 'schema_version 11' <<<"$output" || fail "schema failure must name the version"

# --- verification failure: exit 7 --------------------------------------------
rc=0
run_client missing-entry sync lisa-home-01 "$DATASET" >/dev/null || rc=$?
[ "$rc" -eq 7 ] || fail "missing stored entry must exit 7, got $rc"

# --- mismatched summary is still reported (bash layer decides) ----------------
output="$(run_client mismatch sync lisa-home-01 "$DATASET")" || fail "mismatch scenario should exit 0 at client level"
grep -q '^stored.network_name=OTHER-NET$' <<<"$output" || fail "client must report the stored summary verbatim"

# --- timeout: exit 5 -----------------------------------------------------------
rc=0
run_client timeout sync lisa-home-01 "$DATASET" >/dev/null || rc=$?
[ "$rc" -eq 5 ] || fail "response timeout must exit 5, got $rc"
rc=0
run_client no-server-info credentials >/dev/null || rc=$?
[ "$rc" -eq 5 ] || fail "server-info timeout must exit 5, got $rc"

# --- socket problems: exit 3 ----------------------------------------------------
rc=0
run_client disconnect sync lisa-home-01 "$DATASET" >/dev/null || rc=$?
[ "$rc" -eq 3 ] || fail "disconnect must exit 3, got $rc"
rc=0
run_client connect-fail credentials >/dev/null || rc=$?
[ "$rc" -eq 3 ] || fail "connect failure must exit 3, got $rc"

# --- usage validation: exit 2, no secrets --------------------------------------
rc=0
output="$(run_client ok sync lisa-home-01 "not-hex")" || rc=$?
[ "$rc" -eq 2 ] || fail "invalid dataset must exit 2, got $rc"
rc=0
run_client ok sync "" "$DATASET" >/dev/null || rc=$?
[ "$rc" -eq 2 ] || fail "sync without credential id must exit 2, got $rc"
rc=0
run_client ok bogus-command >/dev/null || rc=$?
[ "$rc" -eq 2 ] || fail "unknown command must exit 2, got $rc"

# --- credential listing ----------------------------------------------------------
output="$(run_client ok credentials)" || fail "credentials listing failed"
grep -q '^thread_credential_count=2$' <<<"$output" || fail "credential count must be printed"
grep -q '^thread_credential.1.id=default$' <<<"$output" || fail "reserved default entry must be listed"

# --- status (fabric label + node count) --------------------------------------------
output="$(run_client ok status)" || fail "status failed"
grep -q '^fabric_label=LISA Home$' <<<"$output" || fail "fabric label must be printed"
grep -q '^node_count=2$' <<<"$output" || fail "node count must be printed"

# --- remove with verification ---------------------------------------------------
# The mock still returns lisa-home-01 after removal, so remove must fail verification.
rc=0
run_client ok remove lisa-home-01 >/dev/null || rc=$?
[ "$rc" -eq 7 ] || fail "remove must verify absence via get_all_credentials, got $rc"
output="$(run_client missing-entry remove lisa-home-01)" || fail "verified removal must succeed"
grep -q '^remove.result=ok$' <<<"$output" || fail "remove must report ok"

echo "Matter WebSocket client tests passed."
