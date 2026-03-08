#!/usr/bin/env bash
# Copy pen source to the e2e test user's home and create a test project directory.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: must be run as root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/test-user-guard.sh"

TARGET="${1:?Usage: copy-pen-source.sh <username>}"
verify_target_user_and_uid "$TARGET"

SRC="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
DEST="/Users/$TARGET/pen-source"
TEST_PROJECT="/Users/$TARGET/test-project"

verify_target_path "$DEST"
verify_target_path "$TEST_PROJECT"
readonly TARGET SRC DEST TEST_PROJECT

cp -R "$SRC" "$DEST"
chown -R "$TARGET:staff" "$DEST"
mkdir -p "$TEST_PROJECT"
chown "$TARGET:staff" "$TEST_PROJECT"
