#!/usr/bin/env bash
# Unit tests for install/usb/config/ubuntu-releases.json and the
# parsing helpers in install/usb/scripts/build/platform/linux/fetch-ubuntu-iso.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG="$REPO_ROOT/install/usb/config/ubuntu-releases.json"
FETCH="$REPO_ROOT/install/usb/scripts/build/platform/linux/fetch-ubuntu-iso.sh"

fail() {
  echo "USB RELEASE CONFIG ERROR: $*" >&2
  exit 1
}

command -v python3 >/dev/null || fail "python3 is required for this test"

echo "Checking ubuntu-releases.json structure..."
python3 - "$CONFIG" <<'PY' || exit 1
import json, re, sys

path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception as exc:
    sys.exit(f"USB RELEASE CONFIG ERROR: invalid JSON in {path}: {exc}")

def err(msg):
    sys.exit(f"USB RELEASE CONFIG ERROR: {msg}")

default = data.get("default")
releases = data.get("releases")
if not isinstance(default, str) or not default:
    err('missing or empty "default"')
if not isinstance(releases, dict) or not releases:
    err('missing or empty "releases"')
if default not in releases:
    err(f'"default" ({default}) has no entry under "releases"')

for name, entry in releases.items():
    mirror = entry.get("mirror", "")
    if not mirror.startswith("https://"):
        err(f'release {name}: "mirror" must use https, got: {mirror!r}')
    if mirror.endswith("/"):
        err(f'release {name}: "mirror" must not end with a slash')
    iso = entry.get("iso", "")
    if iso and not re.fullmatch(r"ubuntu-[0-9][0-9.]*-[a-z-]+-[a-z0-9]+\.iso", iso):
        err(f'release {name}: pinned "iso" does not look like an Ubuntu ISO name: {iso!r}')
    sha = entry.get("sha256", "")
    if sha and not re.fullmatch(r"[0-9a-f]{64}", sha):
        err(f'release {name}: pinned "sha256" must be 64 lowercase hex chars')
    if sha and not iso:
        err(f'release {name}: "sha256" is pinned but "iso" is not; pin both or neither')
PY

echo "Checking fetch-ubuntu-iso.sh helpers..."
# shellcheck disable=SC1090
. "$FETCH"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

value="$(CONFIG_FILE="$CONFIG" json_get '.default')"
[ -n "$value" ] || fail "json_get could not read .default"

mirror="$(CONFIG_FILE="$CONFIG" json_get ".releases.\"$value\".mirror")"
case "$mirror" in
  https://*) ;;
  *) fail "json_get returned a non-https mirror for the default release: $mirror" ;;
esac

sums="$tmp_dir/SHA256SUMS"
cat > "$sums" <<'SUMS'
1111111111111111111111111111111111111111111111111111111111111111 *ubuntu-24.04.9-desktop-amd64.iso
2222222222222222222222222222222222222222222222222222222222222222 *ubuntu-24.04.9-live-server-amd64.iso
3333333333333333333333333333333333333333333333333333333333333333 *ubuntu-24.04.9-live-server-arm64.iso
SUMS

result="$(sums_find_flavor "$sums" live-server amd64)"
[ "$result" = "2222222222222222222222222222222222222222222222222222222222222222 ubuntu-24.04.9-live-server-amd64.iso" ] ||
  fail "sums_find_flavor picked the wrong entry: $result"

hash_value="$(sums_lookup "$sums" ubuntu-24.04.9-desktop-amd64.iso)"
[ "$hash_value" = "1111111111111111111111111111111111111111111111111111111111111111" ] ||
  fail "sums_lookup returned the wrong hash: $hash_value"

result="$(sums_find_flavor "$sums" live-server riscv64 || true)"
[ -z "$result" ] || fail "sums_find_flavor matched a non-existent arch: $result"

echo "USB release config tests passed."
