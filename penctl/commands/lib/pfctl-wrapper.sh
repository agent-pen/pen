#!/usr/bin/env bash
# Wrapper for pfctl operations, scoped to pen anchors only.
# Intended to be called via sudo with NOPASSWD.

set -o nounset -o errexit -o pipefail

anchor_prefix="com.apple/pen-"
anchor="${2:?anchor required}"
[[ "$anchor" == ${anchor_prefix}* ]] || { echo "Anchor must start with ${anchor_prefix}" >&2; exit 1; }

case "${1:-}" in
  flush)
    pfctl -a "$anchor" -F all 2>/dev/null || true
    ;;
  load)
    pfctl -a "$anchor" -f - 2>/dev/null
    pfctl -E 2>/dev/null || true
    ;;
  *)
    echo "Usage: pfctl-wrapper.sh {flush|load} <anchor>" >&2
    exit 1
    ;;
esac
