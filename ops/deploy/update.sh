#!/usr/bin/env bash
set -euo pipefail

EDGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$EDGE_REPO"

CLEAN_MODE=0
case "${1:-}" in
  "") ;;
  clean)
    CLEAN_MODE=1
    ;;
  *)
    echo "Usage: lisa-edge update [clean]" >&2
    echo "  clean  Discard local changes to tracked files and reset to the remote branch." >&2
    exit 2
    ;;
esac

if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  if [ "$CLEAN_MODE" -eq 1 ]; then
    UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
    if [ -z "$UPSTREAM" ]; then
      echo "ERROR: the current branch has no upstream; cannot run 'update clean'." >&2
      exit 1
    fi
    echo "[LISA] Discarding local changes to tracked files and syncing with $UPSTREAM..."
    echo "[LISA] Untracked files (.env, runtime data, secrets) are preserved."
    git fetch
    git reset --hard "$UPSTREAM"
  else
    git pull --ff-only
  fi
fi

"$EDGE_REPO/ops/deploy/deploy.sh" --pull
