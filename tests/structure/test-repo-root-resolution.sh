#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

fail() {
  echo "REPO ROOT ERROR: $*" >&2
  exit 1
}

assert_resolution() {
  local file="$1"
  local variable="$2"
  local traversal="$3"
  local declaration resolved

  [ -f "$file" ] || fail "missing canonical script: $file"
  declaration="$(grep -m 1 -E "^${variable}=" "$file" || true)"
  [ -n "$declaration" ] || fail "$file does not declare $variable"
  case "$declaration" in
    *"$traversal"*) ;;
    *) fail "$file uses the wrong traversal for $variable: $declaration" ;;
  esac

  resolved="$(cd "$(dirname "$file")/$traversal" && pwd)"
  [ "$resolved" = "$REPO_ROOT" ] ||
    fail "$file traversal resolves to $resolved instead of $REPO_ROOT"
}

two_levels=(
  install/bootstrap/bootstrap.sh:REPO_DIR
  install/bootstrap/finalize-admin-access.sh:EDGE_REPO
  install/provisioning/lisa-first-boot.sh:EDGE_REPO
  ops/deploy/deploy.sh:EDGE_REPO
  ops/deploy/healthcheck.sh:EDGE_REPO
  ops/deploy/install-systemd.sh:EDGE_REPO
  ops/deploy/reset-node.sh:EDGE_REPO
  ops/deploy/status.sh:EDGE_REPO
  ops/deploy/stop.sh:EDGE_REPO
  ops/deploy/update.sh:EDGE_REPO
  ops/backup-restore/backup.sh:EDGE_REPO
  ops/backup-restore/restore.sh:EDGE_REPO
  ops/diagnostics/collect-diag.sh:EDGE_DIR
  services/mqtt/prepare.sh:EDGE_REPO
)
for item in "${two_levels[@]}"; do
  assert_resolution "${item%%:*}" "${item#*:}" ../..
done

three_levels=(
  services/otbr/dataset/backup.sh
  services/otbr/dataset/init-or-restore.sh
  services/otbr/dataset/restore.sh
)
for file in "${three_levels[@]}"; do
  assert_resolution "$file" EDGE_REPO ../../..
done

assert_resolution lib/compose.sh LISA_REPO_ROOT ..

echo "Canonical repository-root resolution contract passed."
