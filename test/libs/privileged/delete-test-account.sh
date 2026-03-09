#!/usr/bin/env bash
# Delete the macOS user account for the e2e test user. No-op if user doesn't exist.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/target-user-guards.sh"
require_root

TARGET="${1:?Usage: delete-test-account.sh <username>}"
ensure_correct_target_user "$TARGET"
readonly TARGET

if ! id "$TARGET" &>/dev/null; then
  exit 0
fi

ensure_correct_target_user_and_uid "$TARGET"
TARGET_UID="$(resolve_target_uid "$TARGET")"
readonly TARGET_UID

flush_pf_anchors() {
  pfctl -a com.apple -s Anchors 2>/dev/null | grep "^ *com.apple/pen-user-${TARGET_UID}-project-" | while read -r anchor; do
    pfctl -a "$anchor" -F all 2>/dev/null || true
  done || true
}

force_kill_processes() {
  pkill -9 -u "$TARGET_UID" 2>/dev/null || true
  sleep 1
}

delete_account() {
  # sysadminctl -deleteUser fails if the home directory is missing.
  # Ensure it exists and is owned by the user so sysadminctl deletes it.
  mkdir -p "/Users/$TARGET"
  chown "$TARGET" "/Users/$TARGET"
  sysadminctl -deleteUser "$TARGET" 2>&1 || true
}

# Sweep orphaned launchd domain. Must run after account deletion — if run
# before, the still-valid UID causes launchd to re-bootstrap system agents.
# We bootout unconditionally without checking (launchctl print would
# re-materialize the domain via lazy instantiation).
bootout_launchd_domain() {
  launchctl bootout "user/$TARGET_UID" 2>/dev/null || true
}

force_kill_processes
flush_pf_anchors
delete_account
bootout_launchd_domain
