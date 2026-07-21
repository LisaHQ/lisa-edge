#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  # Install Docker through its signed apt repository. Avoid executing a remote
  # convenience script as root so package provenance remains auditable.
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) ;;
    *) echo "Unsupported distribution for Docker apt repository: ${ID:-unknown}" >&2; exit 1 ;;
  esac

  CODENAME="${VERSION_CODENAME:-}"
  [ -n "$CODENAME" ] || { echo "VERSION_CODENAME is missing from /etc/os-release" >&2; exit 1; }
  ARCH="$(dpkg --print-architecture)"
  KEYRING_DIR=/etc/apt/keyrings
  KEYRING="$KEYRING_DIR/docker.asc"
  KEYRING_TMP="$(mktemp)"
  trap 'rm -f "$KEYRING_TMP"' EXIT

  install -d -m 0755 "$KEYRING_DIR"
  curl -fsSL "https://download.docker.com/linux/$ID/gpg" -o "$KEYRING_TMP"
  grep -q 'BEGIN PGP PUBLIC KEY BLOCK' "$KEYRING_TMP" || {
    echo "Downloaded Docker signing key is not an ASCII-armored public key." >&2
    exit 1
  }
  install -m 0644 "$KEYRING_TMP" "$KEYRING"

  cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/$ID
Suites: $CODENAME
Components: stable
Architectures: $ARCH
Signed-By: $KEYRING
EOF

  apt-get update
  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
  rm -f "$KEYRING_TMP"
  trap - EXIT
fi

docker compose version >/dev/null 2>&1 || {
  echo "Docker Compose plugin is not available." >&2
  exit 1
}

systemctl enable docker
systemctl start docker
