#!/usr/bin/env bash
# Remove sudoers entries for the e2e test user. No-op if entries don't exist.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/test-user-guard.sh"
require_root

TARGET="${1:?Usage: remove-test-sudoers.sh <username>}"
verify_target_user_and_uid "$TARGET"
readonly TARGET

uid="$(id -u "$TARGET" 2>/dev/null || true)"
if [[ -n "$uid" ]]; then
  rm -f "/etc/sudoers.d/pen-${uid}-test"
  rm -f "/etc/sudoers.d/pen-${uid}"
fi
