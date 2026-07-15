#!/usr/bin/env bash
set -euo pipefail

echo "Applying basic host hardening..."

# Disable SSH password login only after confirming that at least one account
# has a non-empty authorized_keys file. This avoids locking out fresh hosts.
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_DROP_IN_DIR="/etc/ssh/sshd_config.d"
SSHD_DROP_IN="$SSHD_DROP_IN_DIR/99-lisa-edge-hardening.conf"
HAS_AUTHORIZED_KEY=0

while IFS= read -r key_file; do
  if grep -Eq '^[[:space:]]*(ssh-|ecdsa-|sk-)' "$key_file"; then
    HAS_AUTHORIZED_KEY=1
    break
  fi
done < <(find /root /home -type f -path '*/.ssh/authorized_keys' 2>/dev/null)

if [ -f "$SSHD_CONFIG" ]; then
  mkdir -p "$SSHD_DROP_IN_DIR"
  {
    echo "PermitRootLogin no"
    if [ "$HAS_AUTHORIZED_KEY" -eq 1 ]; then
      echo "PasswordAuthentication no"
      echo "KbdInteractiveAuthentication no"
    else
      echo "# Password authentication remains enabled: no authorized key was found."
    fi
  } > "$SSHD_DROP_IN"

  if command -v sshd >/dev/null 2>&1; then
    sshd -t
  fi

  systemctl reload ssh || systemctl reload sshd || true

  if [ "$HAS_AUTHORIZED_KEY" -ne 1 ]; then
    echo "WARNING: No authorized SSH key found; password authentication was not disabled." >&2
  fi
fi

echo "Host hardening completed."
