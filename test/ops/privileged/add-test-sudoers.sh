#!/usr/bin/env bash
# Create a scoped sudoers file allowing the e2e test user to run install/uninstall.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/test-user-guard.sh"
require_root

TARGET="${1:?Usage: add-test-sudoers.sh <username>}"
verify_target_user_and_uid "$TARGET"
TARGET_UID="$(resolve_target_uid "$TARGET")"

PEN_SOURCE="/Users/$TARGET/pen-source"
verify_target_path "$PEN_SOURCE"

SUDOERS_FILE="/etc/sudoers.d/pen-${TARGET_UID}-test"
readonly TARGET PEN_SOURCE TARGET_UID SUDOERS_FILE

cat > "$SUDOERS_FILE" <<EOF
$TARGET ALL=(root) NOPASSWD: $PEN_SOURCE/install.sh
$TARGET ALL=(root) NOPASSWD: $PEN_SOURCE/uninstall.sh
EOF
chmod 440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1
