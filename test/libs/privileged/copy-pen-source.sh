#!/usr/bin/env bash
# Copy pen source to the e2e test user's home and create a test project directory.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/target-user-guards.sh"
require_root

TARGET="${1:?Usage: copy-pen-source.sh <username>}"
ensure_correct_target_user_and_uid "$TARGET"

SRC="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
DEST="/Users/$TARGET/pen-source"
TEST_PROJECT="/Users/$TARGET/test-project"

ensure_correct_target_path "$DEST"
ensure_correct_target_path "$TEST_PROJECT"
readonly TARGET SRC DEST TEST_PROJECT

cp -R "$SRC" "$DEST"
chown -R "$TARGET:staff" "$DEST"
mkdir -p "$TEST_PROJECT"
chown "$TARGET:staff" "$TEST_PROJECT"
