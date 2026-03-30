#!/usr/bin/env bash
# Create the e2e test user. Prints the new user's UID to stdout.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/target-user-guards.sh"
require_root

TEST_USER="${1:?Usage: create-test-user.sh <username>}"
ensure_correct_target_user "$TEST_USER"
readonly TEST_USER

create_account() {
  local password
  password="$(openssl rand -hex 16)"

  # Requires the terminal app to have Full Disk Access — see develop.sh.
  sysadminctl -addUser "$TEST_USER" \
    -fullName "pen test user" \
    -password "$password" \
    -home "/Users/$TEST_USER" >&2 || true

  # sysadminctl -createHomeDirectory is broken — use createhomedir instead.
  createhomedir -c -u "$TEST_USER" >&2
}

configure_shell_profile() {
  local home="/Users/$TEST_USER"
  cat > "$home/.zprofile" <<'PROFILE'
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
PROFILE
  chown "$TEST_USER" "$home/.zprofile"
}

create_account
configure_shell_profile

id -u "$TEST_USER"
