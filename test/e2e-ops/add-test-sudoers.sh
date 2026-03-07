#!/usr/bin/env bash
# Create a scoped sudoers file allowing the e2e test user to run install/uninstall.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: must be run as root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/test-user-guard.sh"

TARGET="${1:?Usage: add-test-sudoers.sh <username> <pen-source-path>}"
PEN_SOURCE="${2:?Usage: add-test-sudoers.sh <username> <pen-source-path>}"
verify_target_user_and_uid "$TARGET"
verify_target_path "$PEN_SOURCE"

TARGET_UID="$(id -u "$TARGET")"
SUDOERS_FILE="/etc/sudoers.d/pen-${TARGET_UID}-e2e-test"

cat > "$SUDOERS_FILE" <<EOF
$TARGET ALL=(root) NOPASSWD: $PEN_SOURCE/install.sh
$TARGET ALL=(root) NOPASSWD: $PEN_SOURCE/uninstall.sh
EOF
chmod 440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1
