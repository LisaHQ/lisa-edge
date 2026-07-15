#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat <<'EOF'
LISA Edge Production Reinstall Guide

This command is intentionally non-destructive. It never partitions, formats,
or writes an installer image to a disk.

Recommended production reinstall flow:

1. Collect diagnostics and confirm the failed production disk.
2. Boot from a reviewed Ubuntu production autoinstall USB.
3. Match the intended SSD by serial whenever possible.
4. Reinstall Ubuntu Server on the SSD.
5. Clone lisa-edge into /opt/lisa-edge.
6. Run the LISA Edge setup/bootstrap workflow.
7. Restore a verified LISA Edge backup archive.
8. Verify services before returning the node to production.

Current disk information follows so a human can identify the intended SSD.
EOF

echo
if [[ -x /opt/lisa-rescue/scripts/detect-disks.sh ]]; then
    /opt/lisa-rescue/scripts/detect-disks.sh
else
    bash "$SCRIPT_DIR/detect-disks.sh"
fi

cat <<'EOF'

Next steps:
- Record and confirm the production SSD serial.
- Review the production autoinstall disk match rule.
- Boot from installer USB and confirm the selected target.
- Mount the reinstalled production root if restoring from the Rescue OS.
- Use restore-edge-backup.sh for a LISA Edge backup archive.

Do not install production workloads onto eMMC.
EOF
