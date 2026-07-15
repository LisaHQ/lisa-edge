#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$EDGE_REPO"

if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  git pull --ff-only
fi

"$EDGE_REPO/scripts/deploy.sh"
