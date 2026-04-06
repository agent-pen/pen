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

ensure_correct_target_path "$DEST"
readonly TARGET SRC DEST

rsync -a --delete "$SRC/" "$DEST/"

# Replace the default Dockerfile with a single-line FROM pointing to the
# pre-built test image. This avoids a slow full build during tests while
# still exercising the real pen build path.
echo "FROM pen-test-minimal" > "$DEST/penctl/image/Dockerfile"

chown -R "$TARGET:staff" "$DEST"
