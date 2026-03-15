#!/usr/bin/env bash
# Clear all pen pf anchors for the invoking user.
# Must be run via sudo. Self-contained — no user-writable dependencies.
set -o nounset -o errexit -o pipefail

# Resolve the real (non-root) UID of the invoking user.
uid="${SUDO_UID:?clear-pf-anchors.sh must be run via sudo}"

# List anchors, clear each matching this user's pen anchors.
pfctl -s anchors 2>/dev/null | grep "^com\\.apple/pen-user-${uid}-project-" | while IFS= read -r anchor; do
  pfctl -a "$anchor" -F all 2>/dev/null || true
done || true
