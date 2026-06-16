#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

REPO_URL="${REPO_URL:-https://github.com/LisaHQ/lisa-edge.git}"
BRANCH="${BRANCH:-main}"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "[INFO] Updating rescue scripts from $REPO_URL branch $BRANCH"

git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP_DIR/lisa-edge"

if [[ ! -d "$TMP_DIR/lisa-edge/rescue/scripts" ]]; then
    echo "ERROR: rescue/scripts not found in repo."
    exit 1
fi

install -d -m 0755 /opt/lisa-rescue/scripts
cp "$TMP_DIR/lisa-edge/rescue/scripts/"*.sh /opt/lisa-rescue/scripts/
chmod +x /opt/lisa-rescue/scripts/*.sh

echo "[INFO] Rescue scripts updated."
