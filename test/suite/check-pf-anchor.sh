#!/usr/bin/env bash
# Check whether a pen pf anchor exists (has rules loaded).
# Must be run via sudo. Self-contained — no user-writable dependencies.
# Exit 0 if the anchor exists, 1 otherwise.
set -o nounset -o errexit -o pipefail

uid="${SUDO_UID:?check-pf-anchor.sh must be run via sudo}"
anchor="${1:?Usage: check-pf-anchor.sh <anchor>}"

# Only allow checking this user's pen anchors.
required_prefix="com.apple/pen-user-${uid}-project-"
[[ "$anchor" == ${required_prefix}* ]] || { echo "Anchor must start with ${required_prefix}" >&2; exit 1; }

# Check if the anchor has rules loaded (non-empty output = anchor exists).
rules="$(pfctl -a "$anchor" -s rules 2>/dev/null)"
[[ -n "$rules" ]]
