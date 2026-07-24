#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

fail() {
  echo "LAYOUT ERROR: $*" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "required file is missing: $1"
}

require_dir() {
  [ -d "$1" ] || fail "required directory is missing: $1"
}

echo "Checking canonical layout..."
for directory in docs install services ops rescue lib tests tools; do
  require_dir "$directory"
done

canonical_files=(
  lisa-edge
  lisa-edge.cmd
  .env.template
  install/bootstrap/bootstrap.sh
  install/provisioning/lisa-first-boot.sh
  install/usb/config/ubuntu-releases.json
  install/usb/config/production/user-data.template
  install/usb/config/rescue/user-data.template
  install/usb/scripts/build/build-ubuntu-usb.sh
  install/usb/scripts/build/build-ubuntu-usb.cmd
  install/usb/scripts/build/platform/linux/fetch-ubuntu-iso.sh
  install/usb/scripts/build/platform/linux/create-usb-disk.sh
  install/usb/scripts/build/platform/windows/fetch-ubuntu-iso.ps1
  install/usb/scripts/build/platform/windows/create-usb-disk.ps1
  install/usb/scripts/prepare/prepare-production-usb.sh
  install/usb/scripts/prepare/prepare-production-usb.cmd
  install/usb/scripts/prepare/prepare-rescue-usb.sh
  install/usb/scripts/prepare/prepare-rescue-usb.cmd
  services/registry.sh
  services/list.sh
  ops/deploy/compose.yml
  ops/deploy/deploy.sh
  ops/deploy/healthcheck.sh
  ops/backup-restore/backup.sh
  ops/backup-restore/restore.sh
  ops/backup-restore/lib/validate_backup.py
  ops/diagnostics/collect-diag.sh
  rescue/scripts/bootstrap.sh
  rescue/scripts/restore-edge-backup.sh
  rescue/scripts/restore-filesystem-snapshot.sh
  lib/compose.sh
  lib/images.sh
  lib/paths.sh
  lib/service-config.sh
  lib/thread-dataset.sh
  services/otbr/status.sh
  services/otbr/network-create.sh
  services/otbr/dataset/show.sh
  services/otbr/dataset/export.sh
  services/otbr/dataset/backup.sh
  services/otbr/dataset/restore.sh
  services/otbr/dataset/init-or-restore.sh
  services/matter-server/status.sh
  services/matter-server/thread.sh
  services/matter-server/credentials.sh
  services/matter-server/lib/ws.sh
  services/matter-server/lib/ws-client.js
  services/matter-server/compose.ble.yml
  services/matter-server/compose.primary-interface.yml
  services/matter-server/data/reset.sh
  ops/diagnostics/doctor-matter-thread.sh
  tests/README.md
  tools/validate-repo.sh
)
for file in "${canonical_files[@]}"; do
  require_file "$file"
done

echo "Checking service registry slices..."
# shellcheck disable=SC1091
. "$REPO_ROOT/services/registry.sh"
declare -A service_directories=()
for service in $LISA_ALL_SERVICES; do
  directory="$(lisa_service_directory "$service")" ||
    fail "registry has no directory mapping for service: $service"
  [ -z "${service_directories[$directory]:-}" ] ||
    fail "multiple service IDs map to the same directory: $directory"
  service_directories[$directory]="$service"
  require_file "services/$directory/compose.yml"
  require_file "services/$directory/provision.sh"

  for dependency in $(lisa_service_dependencies "$service"); do
    case " $LISA_ALL_SERVICES " in
      *" $dependency "*) ;;
      *) fail "$service declares unknown dependency: $dependency" ;;
    esac
  done
done

echo "Checking stable operator CLI..."
help_output="$(bash "$REPO_ROOT/lisa-edge" help)"
for command in \
  setup configure bootstrap deploy stop update health status diagnostics \
  backup restore reset usb rescue service otbr matter doctor
do
  grep -Fq "$command" <<<"$help_output" ||
    fail "CLI help does not advertise command: $command"
done
for reset_line in \
  'reset data' 'reset provisioning' 'reset factory'
do
  grep -Fq "$reset_line" <<<"$help_output" ||
    fail "CLI help does not advertise reset mode: $reset_line"
done

service_output="$(bash "$REPO_ROOT/lisa-edge" service list)"
for service in $LISA_ALL_SERVICES; do
  grep -Eq "^${service}[[:space:]]" <<<"$service_output" ||
    fail "service list does not include registry ID: $service"
done

bash "$REPO_ROOT/lisa-edge" restore --help >/dev/null 2>&1
bash "$REPO_ROOT/lisa-edge" rescue restore-backup --help >/dev/null 2>&1
bash "$REPO_ROOT/lisa-edge" otbr dataset show --help >/dev/null 2>&1
bash "$REPO_ROOT/lisa-edge" matter thread --help >/dev/null 2>&1
bash "$REPO_ROOT/lisa-edge" doctor matter-thread --help >/dev/null 2>&1
if bash "$REPO_ROOT/lisa-edge" definitely-not-a-command >/dev/null 2>&1; then
  fail "unknown CLI command was accepted"
fi

echo "Checking Windows day-0 CLI targets..."
grep -Fq 'install\usb\scripts\prepare\prepare-production-usb.cmd' lisa-edge.cmd ||
  fail "lisa-edge.cmd does not target the canonical production USB script"
grep -Fq 'install\usb\scripts\prepare\prepare-rescue-usb.cmd' lisa-edge.cmd ||
  fail "lisa-edge.cmd does not target the canonical rescue USB script"
grep -Fq 'install\usb\scripts\build\build-ubuntu-usb.cmd' lisa-edge.cmd ||
  fail "lisa-edge.cmd does not target the canonical USB build script"

echo "Checking installed /opt/lisa-edge path literals..."
installed_assets=()
while IFS= read -r -d '' file; do
  installed_assets+=("$file")
done < <(
  find \
    install/usb \
    install/provisioning/systemd \
    ops/deploy/systemd \
    ops/backup-restore/systemd \
    services/otbr/systemd \
    services/matter-server/systemd \
    -type f \
    \( -name 'user-data' -o -name 'user-data.template' -o -name '*.service' -o -name '*.timer' \) \
    -print0
)
[ "${#installed_assets[@]}" -gt 0 ] || fail "no autoinstall or systemd assets found"

installed_literals=()
while IFS= read -r literal; do
  [ -n "$literal" ] && installed_literals+=("$literal")
done < <(
  grep -hEo '/opt/lisa-edge(/[A-Za-z0-9._-]+)*' "${installed_assets[@]}" |
    sort -u || true
)
[ "${#installed_literals[@]}" -gt 0 ] ||
  fail "no /opt/lisa-edge literals found in installation assets"

for literal in "${installed_literals[@]}"; do
  relative="${literal#/opt/lisa-edge}"
  [ -e "$REPO_ROOT$relative" ] ||
    fail "installed path has no repository target: $literal"
done

echo "Checking forbidden stale installed paths..."
stale_absolute='/opt/lisa-edge/(bootstrap|provisioning|scripts|recovery|usb-installer|compose|config|systemd)(/|$)'
if grep -RInE "$stale_absolute" \
  install ops services rescue lib \
  --include='*.sh' \
  --include='*.py' \
  --include='*.service' \
  --include='*.timer' \
  --include='*.template' \
  --include='user-data'
then
  fail "canonical implementation contains a stale installed path"
fi

if grep -RInE \
  '\$REPO_ROOT/(scripts/lib|provisioning|bootstrap|usb-installer)/' \
  tests/unit tests/security tests/integration
then
  fail "canonical tests source a deprecated implementation path"
fi

echo "Checking removed legacy paths stay removed..."
legacy_paths=(
  install/usb/production
  install/usb/rescue
  bootstrap
  provisioning
  scripts
  recovery
  usb-installer
  compose
  config
  systemd
  test
  rescue/scripts/bootstrap-rescue.sh
  rescue/scripts/reinstall-production.sh
  rescue/scripts/restore-production.sh
  services/matter-server/data/sync-thread-dataset.sh
)
for path in "${legacy_paths[@]}"; do
  [ ! -e "$path" ] ||
    fail "legacy path must not reappear: $path (use the canonical layout)"
done

echo "Repository layout contract passed."
