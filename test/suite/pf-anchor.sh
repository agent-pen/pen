#!/usr/bin/env bash
# Manage pen pf anchors for the invoking user.
# Must be run via sudo. Self-contained — no user-writable dependencies.
#
# Usage:
#   pf-anchor.sh read <anchor>    Exit 0 if anchor has rules, 1 otherwise.
#   pf-anchor.sh flush             Flush all pen anchors for this user.
#   pf-anchor.sh flush <anchor>    Flush a specific pen anchor.
set -o nounset -o errexit -o pipefail

uid="${SUDO_UID:?pf-anchor.sh must be run via sudo}"
anchor_prefix="com.apple/pen-user-${uid}-project-"

validate_anchor() {
  local anchor="$1"
  [[ "$anchor" == ${anchor_prefix}* ]] || {
    echo "Anchor must start with ${anchor_prefix}" >&2
    exit 1
  }
}

case "${1:-}" in
  read)
    anchor="${2:?Usage: pf-anchor.sh read <anchor>}"
    validate_anchor "$anchor"
    rules="$(pfctl -a "$anchor" -s rules 2>/dev/null)"
    [[ -n "$rules" ]]
    ;;
  flush)
    if [[ -n "${2:-}" ]]; then
      validate_anchor "$2"
      pfctl -a "$2" -F all 2>/dev/null || true
    else
      local short_prefix="pen-user-${uid}-project-"
      pfctl -a 'com.apple' -s Anchors 2>/dev/null \
        | grep "^${short_prefix}" \
        | while IFS= read -r name; do
            pfctl -a "com.apple/${name}" -F all 2>/dev/null || true
          done || true
    fi
    ;;
  *)
    echo "Usage: pf-anchor.sh {read|flush} [anchor]" >&2
    exit 1
    ;;
esac
