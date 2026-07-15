#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FAILED=0
WARNED=0

check_ok() {
    echo "OK: $*"
}

check_warn() {
    echo "WARN: $*"
    WARNED=1
}

check_fail() {
    echo "FAIL: $*"
    FAILED=1
}

exists_file() {
    local path="$1"
    local label="$2"
    if [[ -f "$REPO_ROOT/$path" ]]; then
        check_ok "$label exists: $path"
    else
        check_fail "$label missing: $path"
    fi
}

exists_dir() {
    local path="$1"
    local label="$2"
    if [[ -d "$REPO_ROOT/$path" ]]; then
        check_ok "$label exists: $path"
    else
        check_fail "$label missing: $path"
    fi
}

grep_file() {
    local pattern="$1"
    local path="$2"
    local label="$3"
    if [[ -f "$REPO_ROOT/$path" ]] && grep -Eq "$pattern" "$REPO_ROOT/$path"; then
        check_ok "$label"
    else
        check_warn "$label not confirmed"
    fi
}

echo
echo "========================================"
echo "LISA Edge Disaster Recovery Check"
echo "========================================"
echo

exists_file "README.md" "README"
exists_file "lisa-edge" "Stable operator command"
for directory in docs install services ops rescue lib tests; do
    exists_dir "$directory" "Canonical $directory directory"
done

exists_file "docs/operations/backup-restore.md" "Backup/restore documentation"
exists_file "docs/operations/disaster-recovery.md" "Disaster recovery documentation"
exists_file "docs/operations/service-recovery/otbr.md" "OTBR recovery documentation"
exists_file "docs/getting-started/05-deployment-validation.md" "Deployment validation checklist"

exists_file "ops/backup-restore/backup.sh" "Canonical backup command"
exists_file "ops/backup-restore/restore.sh" "Canonical restore command"
exists_file "ops/backup-restore/lib/validate_backup.py" "Privileged archive validator"
exists_file "ops/deploy/healthcheck.sh" "Canonical health check"
exists_file "services/otbr/dataset/backup.sh" "OTBR dataset backup"
exists_file "services/otbr/dataset/restore.sh" "OTBR dataset restore"
exists_file "rescue/scripts/restore-edge-backup.sh" "Rescue archive restore wrapper"
exists_file "rescue/scripts/restore-filesystem-snapshot.sh" "Rescue filesystem restore"

grep_file "Thread Dataset|dataset" "docs/operations/service-recovery/otbr.md" \
    "OTBR recovery mentions Thread Dataset"
grep_file "restore" "docs/operations/backup-restore.md" \
    "Backup documentation mentions restore"
grep_file "VPN|SSH" "README.md" \
    "README mentions remote administration or secure access"
grep_file "eMMC|Rescue" "README.md" \
    "README mentions rescue/eMMC layer"
grep_file "SSD|Production" "README.md" \
    "README mentions production/SSD layer"

echo
echo "-- Layout contract --"
if bash "$REPO_ROOT/tests/structure/test-layout.sh"; then
    check_ok "Canonical layout contract passed"
else
    check_fail "Canonical layout contract failed"
fi
if bash "$REPO_ROOT/tests/structure/test-repo-root-resolution.sh"; then
    check_ok "Canonical repository-root resolution passed"
else
    check_fail "Canonical repository-root resolution failed"
fi

echo
echo "-- Executable script check --"
while IFS= read -r script; do
    rel="${script#$REPO_ROOT/}"
    if [[ -x "$script" ]]; then
        check_ok "Executable: $rel"
    else
        check_warn "Not executable: $rel"
    fi
done < <(
    find \
        "$REPO_ROOT/install" \
        "$REPO_ROOT/services" \
        "$REPO_ROOT/ops" \
        "$REPO_ROOT/rescue" \
        "$REPO_ROOT/tools" \
        "$REPO_ROOT/tests" \
        -type f -name '*.sh' |
        sort
)

echo
echo "-- Compose validation --"
if [[ -x "$REPO_ROOT/tools/validate-compose.sh" ]]; then
    if "$REPO_ROOT/tools/validate-compose.sh"; then
        check_ok "Compose validation passed"
    else
        check_fail "Compose validation failed"
    fi
else
    check_warn "tools/validate-compose.sh missing or not executable"
fi

echo
echo "========================================"
echo "Summary"
echo "========================================"

if [[ "$FAILED" -ne 0 ]]; then
    echo "Result: FAIL"
    exit 1
fi
if [[ "$WARNED" -ne 0 ]]; then
    echo "Result: PASS WITH WARNINGS"
    exit 0
fi

echo "Result: PASS"
