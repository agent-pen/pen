#!/usr/bin/env bash
# Grant the e2e test user privileged execution of install.sh and uninstall.sh:
# root-own the scripts (so the test user cannot modify them) and create a
# scoped sudoers file (so the test user can run them as root without a password).
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/target-user-guards.sh"
require_root

TARGET="${1:?Usage: grant-test-privileges.sh <username>}"
ensure_correct_target_user_and_uid "$TARGET"
TARGET_UID="$(resolve_target_uid "$TARGET")"

PEN_SOURCE="/Users/$TARGET/pen-source"
INSTALL="$PEN_SOURCE/install.sh"
UNINSTALL="$PEN_SOURCE/uninstall.sh"
SUDOERS_FILE="/etc/sudoers.d/pen-${TARGET_UID}-test"

ensure_correct_target_path "$PEN_SOURCE"
readonly TARGET PEN_SOURCE INSTALL UNINSTALL TARGET_UID SUDOERS_FILE

require_scripts_exist() {
  for script in "$INSTALL" "$UNINSTALL"; do
    if [[ ! -f "$script" ]]; then
      echo "FATAL: expected script not found: $script" >&2
      exit 1
    fi
  done
}

root_own_scripts() {
  chown root:wheel "$INSTALL" "$UNINSTALL"
}

add_sudoers() {
  cat > "$SUDOERS_FILE" <<EOF
$TARGET ALL=(root) NOPASSWD: $INSTALL
$TARGET ALL=(root) NOPASSWD: $UNINSTALL
EOF
  chmod 440 "$SUDOERS_FILE"
  visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1
}

require_scripts_exist
root_own_scripts
add_sudoers
