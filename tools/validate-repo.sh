#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "Checking canonical layout and compatibility contracts..."
bash "$REPO_ROOT/tests/structure/test-layout.sh"
bash "$REPO_ROOT/tests/structure/test-repo-root-resolution.sh"

echo "Checking Bash syntax..."
bash -n "$REPO_ROOT/lisa-edge"
syntax_roots=(
  install ops rescue services lib tools tests
)
while IFS= read -r -d '' script; do
  bash -n "$script"
done < <(find "${syntax_roots[@]}" -type f -name '*.sh' -print0)

echo "Checking stale file references..."
if grep -RInE --exclude='validate-repo.sh' \
  '\.env\.example|40-mosquitto-defaults\.sh|docs/getting-started/deployment-validation\.md' \
  README.md docs install ops rescue services lib tools tests
then
  echo "Stale file reference found." >&2
  exit 1
fi
if grep -RInE \
  '(\$REPO_ROOT/|bash[[:space:]]+)test/(unit|security|integration)/' \
  tools .github
then
  echo "CI or tools still invoke the deprecated test/ tree." >&2
  exit 1
fi

echo "Checking Docker Compose configurations..."
ENV_FILE="${ENV_FILE:-$REPO_ROOT/.env.template}" \
  bash "$REPO_ROOT/tools/validate-compose.sh"

echo "Checking service selection and image policy..."
bash "$REPO_ROOT/tests/unit/test-service-selection.sh"
bash "$REPO_ROOT/tests/unit/test-image-policy.sh"

echo "Checking provisioning wizard..."
bash "$REPO_ROOT/tests/unit/test-provisioning-wizard.sh"

echo "Checking USB release config..."
bash "$REPO_ROOT/tests/unit/test-usb-release-config.sh"

echo "Checking backup archive validation..."
"$PYTHON_BIN" "$REPO_ROOT/tests/security/test-backup-validation.py"
bash "$REPO_ROOT/tests/security/test-backup-checksum.sh"
bash "$REPO_ROOT/tests/security/test-backup-mount-guard.sh"
bash "$REPO_ROOT/tests/security/test-path-safety.sh"
bash "$REPO_ROOT/tests/security/test-restore-target-root.sh"
bash "$REPO_ROOT/tests/security/test-usb-device-guard.sh"

echo "Checking Rescue OS path guardrails..."
bash "$REPO_ROOT/tests/security/test-recovery-safety.sh"

echo "Checking v2 and v3 restore integration..."
PYTHON_BIN="$PYTHON_BIN" \
  bash "$REPO_ROOT/tests/integration/test-restore-integration.sh"

echo "Repository validation passed."
