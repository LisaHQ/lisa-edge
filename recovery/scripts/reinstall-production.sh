#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
LISA Edge Production Reinstall Helper

This script is intentionally non-destructive.

Recommended production reinstall flow:

1. Boot from Ubuntu autoinstall USB.
2. Use production user-data that targets the SSD.
3. Reinstall Ubuntu Server on SSD.
4. Clone lisa-edge into /opt/lisa-edge.
5. Run bootstrap.
6. Restore persistent data from backup.
7. Verify services.

This helper prints current disk information so you can choose the correct SSD target.
EOF

echo
/opt/lisa-rescue/scripts/detect-disks.sh || bash "$(dirname "$0")/detect-disks.sh"

cat <<'EOF'

Next steps:
- Confirm SSD serial.
- Update production autoinstall user-data.
- Boot from installer USB.
- Restore after install.

Do not install production workloads onto eMMC.
EOF
