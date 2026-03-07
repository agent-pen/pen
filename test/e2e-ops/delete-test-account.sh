#!/usr/bin/env bash
# Delete the macOS user account for the e2e test user. No-op if user doesn't exist.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: must be run as root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/test-user-guard.sh"

TARGET="${1:?Usage: delete-test-account.sh <username>}"
verify_target_user_and_uid "$TARGET"
readonly TARGET

if ! id "$TARGET" &>/dev/null; then
  exit 0
fi

# sysadminctl -deleteUser fails if the home directory is missing.
# Ensure it exists and is owned by the user so sysadminctl deletes it.
mkdir -p "/Users/$TARGET"
chown "$TARGET" "/Users/$TARGET"

sysadminctl -deleteUser "$TARGET" 2>&1 || true
