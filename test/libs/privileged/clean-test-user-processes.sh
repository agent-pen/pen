#!/usr/bin/env bash
# Kill all processes and flush pf anchors for the e2e test user.
# No-op if user doesn't exist. Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/target-user-guards.sh"
require_root

TARGET="${1:?Usage: clean-test-user-processes.sh <username>}"
ensure_correct_target_user "$TARGET"
readonly TARGET

if ! id "$TARGET" &>/dev/null; then
  exit 0
fi

TARGET_UID="$(resolve_target_uid "$TARGET")"
readonly TARGET_UID

pkill -9 -u "$TARGET_UID" 2>/dev/null || true
sleep 1

pfctl -a com.apple -s Anchors 2>/dev/null \
  | grep -o "com.apple/pen-user-${TARGET_UID}-project-[^ ]*" \
  | xargs -P 0 -I{} pfctl -a {} -F all 2>/dev/null \
  || true
