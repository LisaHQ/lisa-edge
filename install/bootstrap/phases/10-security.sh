#!/usr/bin/env bash
set -euo pipefail

echo "Applying basic host hardening..."

# Disable SSH password login only after confirming that a NON-ROOT account
# has a usable authorized_keys file. This drop-in also sets PermitRootLogin
# no, so a key that exists only for root must NOT count - otherwise the host
# would be locked out of all remote access.
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_DROP_IN_DIR="/etc/ssh/sshd_config.d"
SSHD_DROP_IN="$SSHD_DROP_IN_DIR/99-lisa-edge-hardening.conf"
HAS_AUTHORIZED_KEY=0

key_candidates=()
ADMIN_USER="${LISA_ADMIN_USER:-}"
if [ -n "$ADMIN_USER" ] && [ "$ADMIN_USER" != "root" ]; then
  admin_home="$(getent passwd "$ADMIN_USER" | cut -d: -f6 || true)"
  [ -n "$admin_home" ] && key_candidates+=("$admin_home/.ssh/authorized_keys")
fi
while IFS= read -r key_file; do
  key_candidates+=("$key_file")
done < <(find /home -type f -path '*/.ssh/authorized_keys' 2>/dev/null)

for key_file in "${key_candidates[@]}"; do
  [ -f "$key_file" ] || continue
  if grep -Eq '^[[:space:]]*(ssh-|ecdsa-|sk-)' "$key_file"; then
    HAS_AUTHORIZED_KEY=1
    break
  fi
done

if [ "$HAS_AUTHORIZED_KEY" -eq 0 ] && \
  find /root -type f -path '*/.ssh/authorized_keys' 2>/dev/null | grep -q .; then
  echo "WARNING: an SSH key exists only for root, but root login is disabled."
  echo "WARNING: password authentication stays enabled; add a key for the"
  echo "WARNING: admin account and rerun bootstrap to finish hardening."
fi

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
