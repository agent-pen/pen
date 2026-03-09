#!/usr/bin/env bash
# Grant the e2e test user privileged execution of specific scripts:
# for each script, verify it exists, root-own it (so the test user cannot
# modify it), and add a sudoers entry (so the test user can run it as root
# without a password).
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/target-user-guards.sh"
require_root

TARGET="${1:?Usage: grant-test-privileges.sh <username>}"
ensure_correct_target_user_and_uid "$TARGET"
TARGET_UID="$(resolve_target_uid "$TARGET")"

PEN_SOURCE="/Users/$TARGET/pen-source"
SUDOERS_FILE="/etc/sudoers.d/pen-${TARGET_UID}-test"

ensure_correct_target_path "$PEN_SOURCE"
readonly TARGET PEN_SOURCE TARGET_UID SUDOERS_FILE

PRIVILEGED_SCRIPTS=(
  "$PEN_SOURCE/install.sh"
  "$PEN_SOURCE/uninstall.sh"
)
readonly PRIVILEGED_SCRIPTS

grant_privileges() {
  local sudoers_lines=""

  for script in "${PRIVILEGED_SCRIPTS[@]}"; do
    if [[ ! -f "$script" ]]; then
      echo "FATAL: expected script not found: $script" >&2
      exit 1
    fi
    chown root:wheel "$script"
    sudoers_lines+="$TARGET ALL=(root) NOPASSWD: $script"$'\n'
  done

  echo -n "$sudoers_lines" > "$SUDOERS_FILE"
  chmod 440 "$SUDOERS_FILE"
  visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1
}

grant_privileges
