#!/usr/bin/env bash
# Negative tests for the fail-closed device validation in
# install/usb/scripts/build/platform/linux/create-usb-disk.sh.
#
# Uses a fake sysfs/mounts tree; never touches a real device.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CREATE="$REPO_ROOT/install/usb/scripts/build/platform/linux/create-usb-disk.sh"

fail() {
  echo "USB DEVICE GUARD ERROR: $*" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# Fake /sys/block: sdgood = removable whole disk, sdfixed = internal disk.
mkdir -p "$tmp_dir/sys/sdgood" "$tmp_dir/sys/sdfixed"
echo 1 > "$tmp_dir/sys/sdgood/removable"
echo 0 > "$tmp_dir/sys/sdfixed/removable"

# Fake /proc/mounts: sdbusy1 is mounted.
cat > "$tmp_dir/mounts" <<'MOUNTS'
/dev/sda2 / ext4 rw,relatime 0 0
/dev/sdbusy1 /mnt/data ext4 rw,relatime 0 0
MOUNTS

export LISA_TEST_SYS_BLOCK_DIR="$tmp_dir/sys"
export LISA_TEST_PROC_MOUNTS="$tmp_dir/mounts"

# run_guard <expect: pass|reject> <description> <function> <args...>
run_guard() {
  local expect="$1" description="$2"
  shift 2
  local rc=0
  (
    # shellcheck disable=SC1090
    . "$CREATE"
    "$@"
  ) >/dev/null 2>&1 || rc=$?
  case "$expect" in
    pass)
      [ "$rc" -eq 0 ] || fail "should pass but was rejected: $description"
      ;;
    reject)
      [ "$rc" -ne 0 ] || fail "UNSAFE INPUT ACCEPTED: $description"
      ;;
  esac
  echo "  ok: $description"
}

echo "Checking device path validation..."
run_guard reject "empty device path"                     validate_device_path ""
run_guard reject "relative device path"                  validate_device_path "sdb"
run_guard reject "path outside /dev"                     validate_device_path "/tmp/sdb"
run_guard reject "path traversal in device"              validate_device_path "/dev/../etc/passwd"
run_guard reject "device path with spaces"               validate_device_path "/dev/sd b"
run_guard reject "non-existent block device"             validate_device_path "/dev/lisa-does-not-exist"

echo "Checking whole-disk / removable / mounted guards..."
run_guard pass   "removable whole disk accepted"         validate_removable "/dev/sdgood"
run_guard pass   "whole disk accepted"                   validate_whole_disk "/dev/sdgood"
run_guard reject "partition rejected as target"          validate_whole_disk "/dev/sdgood1"
run_guard reject "internal (non-removable) disk"         validate_removable "/dev/sdfixed"
run_guard reject "unknown device (no sysfs entry)"       validate_removable "/dev/sdunknown"
run_guard pass   "unmounted disk accepted"               validate_not_mounted "/dev/sdgood"
run_guard reject "disk with mounted partition"           validate_not_mounted "/dev/sdbusy"

echo "Checking the CLI rejects unsafe invocations..."
rc=0
bash "$CREATE" --iso "$tmp_dir/missing.iso" >/dev/null 2>&1 || rc=$?
[ "$rc" -ne 0 ] || fail "create-usb-disk.sh accepted a run without --device"

rc=0
touch "$tmp_dir/fake.iso"
bash "$CREATE" --device "" --iso "$tmp_dir/fake.iso" >/dev/null 2>&1 || rc=$?
[ "$rc" -ne 0 ] || fail "create-usb-disk.sh accepted an empty --device"

echo "USB device guard tests passed."
