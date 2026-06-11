#!/usr/bin/env bash
set -euo pipefail
if [ $# -ne 1 ]; then echo "Usage: $0 backup.tar.gz" >&2; exit 1; fi
tar -xzf "$1" -C /
