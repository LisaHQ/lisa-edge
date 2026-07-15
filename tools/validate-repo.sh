#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "Checking Bash syntax..."
while IFS= read -r -d '' script; do
  bash -n "$script"
done < <(find bootstrap scripts tools test recovery provisioning usb-installer -type f -name '*.sh' -print0)

echo "Checking stale file references..."
if grep -RInE --exclude='validate-repo.sh' \
  '\.env\.example|40-mosquitto-defaults\.sh|docs/getting-started/deployment-validation\.md' \
  README.md docs bootstrap scripts tools test recovery provisioning usb-installer; then
  echo "Stale file reference found." >&2
  exit 1
fi

echo "Checking Docker Compose configurations..."
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env.template}" bash "$REPO_ROOT/tools/validate-compose.sh"

echo "Checking service selection..."
bash "$REPO_ROOT/test/unit/test-service-selection.sh"
bash "$REPO_ROOT/test/unit/test-image-policy.sh"

echo "Checking provisioning wizard..."
bash "$REPO_ROOT/test/unit/test-provisioning-wizard.sh"

echo "Checking backup archive validation..."
"$PYTHON_BIN" "$REPO_ROOT/test/security/test-backup-validation.py"
bash "$REPO_ROOT/test/security/test-backup-checksum.sh"
bash "$REPO_ROOT/test/security/test-backup-mount-guard.sh"
bash "$REPO_ROOT/test/integration/test-restore-integration.sh"

echo "Checking recovery path guardrails..."
bash "$REPO_ROOT/test/security/test-recovery-safety.sh"

echo "Repository validation passed."
