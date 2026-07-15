# Tools

This directory contains developer, build, and repository-validation utilities.
Normal operator workflows use the root lisa-edge command; canonical runtime
implementations live under ops/.

- validate-repo.sh is the repository-wide CI entrypoint. It checks the layout
  contract, Compose models, unit/security tests, and v2/v3 restore
  integration.
- validate-compose.sh renders the base ops/deploy/compose.yml with service
  fragments discovered through services/registry.sh.
- build-usb.sh prepares production or rescue assets from install/usb/.
- generate-secrets.sh generates values for external secure storage.
- detect-disks.sh reports candidate storage devices without modifying them.
- disaster-recovery-check.sh checks canonical recovery prerequisites.

Run the same validation used by CI:

    bash tools/validate-repo.sh

Most tools target Linux. USB-specific Windows helpers live next to their
canonical profiles under install/usb/.
