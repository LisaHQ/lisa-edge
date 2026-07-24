#!/usr/bin/env bash
set -euo pipefail

# OTBR container-image resolver: Docker Hub tag pagination with bounded
# pages, release-tag selection across pages, offline behavior, and pinned
# image preservation. Network access is mocked by overriding otbr_fetch_url.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/images.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/services/otbr/provision.sh"

fail() {
  echo "OTBR IMAGE RESOLVER TEST ERROR: $*" >&2
  exit 1
}

page() {
  local next="$1"
  shift
  local names="" name
  for name in "$@"; do
    names+="{\"name\": \"$name\"},"
  done
  printf '{"count": 999, "next": %s, "results": [%s]}' "$next" "${names%,}"
}

FETCH_LOG="$(mktemp "${TMPDIR:-/tmp}/otbr-fetch-log.XXXXXX")"
trap 'rm -f "$FETCH_LOG"' EXIT
otbr_fetch_url() {
  printf '%s\n' "$1" >> "$FETCH_LOG"
  case "$1" in
    *page=fail*) return 1 ;;
    *page=2*) printf '%s' "$MOCK_PAGE_2" ;;
    *page=3*) printf '%s' "$MOCK_PAGE_3" ;;
    *) printf '%s' "$MOCK_PAGE_1" ;;
  esac
}

# --- release tag on the first page -----------------------------------------
MOCK_PAGE_1="$(page 'null' latest main v2026.06.0 v2026.07.1)"
result="$(otbr_query_latest_image)" || fail "first-page resolution failed"
[ "$result" = "openthread/border-router:v2026.07.1" ] ||
  fail "expected v2026.07.1 from page 1, got: $result"

# --- release tags only on a later page ---------------------------------------
MOCK_PAGE_1="$(page '"https://hub.docker.com/v2/repositories/openthread/border-router/tags?page=2"' latest main sha-1234567)"
MOCK_PAGE_2="$(page '"https://hub.docker.com/v2/repositories/openthread/border-router/tags?page=3"' nightly sha-89abcde)"
MOCK_PAGE_3="$(page 'null' v2026.05.0 v2026.07.0)"
: > "$FETCH_LOG"
result="$(otbr_query_latest_image)" || fail "multi-page resolution failed"
[ "$result" = "openthread/border-router:v2026.07.0" ] ||
  fail "expected v2026.07.0 from page 3, got: $result"
[ "$(grep -c . "$FETCH_LOG")" -eq 3 ] || fail "expected exactly 3 page fetches"

# --- newest tag wins across pages ---------------------------------------------
MOCK_PAGE_1="$(page '"https://hub.docker.com/v2/repositories/openthread/border-router/tags?page=2"' v2026.07.2 latest)"
MOCK_PAGE_2="$(page 'null' v2026.06.9)"
result="$(otbr_query_latest_image)" || fail "cross-page resolution failed"
[ "$result" = "openthread/border-router:v2026.07.2" ] ||
  fail "the newest release across pages must win, got: $result"

# --- pagination limit is bounded ------------------------------------------------
MOCK_PAGE_1="$(page '"https://hub.docker.com/v2/repositories/openthread/border-router/tags?page=2"' latest)"
MOCK_PAGE_2="$(page '"https://hub.docker.com/v2/repositories/openthread/border-router/tags?page=2"' main)"
: > "$FETCH_LOG"
if OTBR_IMAGE_QUERY_MAX_PAGES=3 otbr_query_latest_image >/dev/null; then
  fail "an endless tag list without releases must fail"
fi
[ "$(grep -c . "$FETCH_LOG")" -eq 3 ] ||
  fail "pagination must stop at OTBR_IMAGE_QUERY_MAX_PAGES"

# --- no release tag anywhere ------------------------------------------------------
MOCK_PAGE_1="$(page 'null' latest main sha-1234567)"
if otbr_query_latest_image >/dev/null; then
  fail "a tag list without release tags must fail"
fi

# --- offline / fetch failure -------------------------------------------------------
MOCK_PAGE_1="$(page '"https://hub.docker.com/v2/repositories/openthread/border-router/tags?page=fail"' latest)"
if otbr_query_latest_image >/dev/null; then
  fail "a failing page fetch must fail the resolution"
fi

# --- hostile next URLs are not followed ----------------------------------------------
MOCK_PAGE_1="$(page '"https://evil.example.com/tags?page=2"' latest v2026.01.1)"
: > "$FETCH_LOG"
result="$(otbr_query_latest_image)" || fail "resolution with hostile next URL failed"
[ "$result" = "openthread/border-router:v2026.01.1" ] || fail "unexpected result: $result"
[ "$(grep -c . "$FETCH_LOG")" -eq 1 ] || fail "non-dockerhub next URLs must not be fetched"

# --- pinned references stay untouched --------------------------------------------------
otbr_image_is_floating "openthread/border-router:latest" || fail "latest must be floating"
if otbr_image_is_floating "openthread/border-router:v2026.07.0"; then
  fail "release tags must not be floating"
fi
if otbr_image_is_floating "openthread/border-router@sha256:$(printf '1%.0s' $(seq 1 64))"; then
  fail "digest-pinned images must not be floating"
fi

echo "OTBR image resolver tests passed."
