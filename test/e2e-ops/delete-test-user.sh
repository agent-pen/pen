#!/usr/bin/env bash
# Delete the e2e test user and clean up sudoers. No-op if user doesn't exist.
# Must be run as root.

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: must be run as root." >&2
  exit 1
fi

TEST_USER="pen-e2e-test-user"

if ! id "$TEST_USER" &>/dev/null; then
  exit 0
fi

uid="$(id -u "$TEST_USER")"

rm -f "/etc/sudoers.d/pen-${uid}-e2e-test"
rm -f "/etc/sudoers.d/pen-${uid}"

# sysadminctl -deleteUser fails if the home directory is missing.
# Ensure it exists and is owned by the user so sysadminctl deletes it.
mkdir -p "/Users/$TEST_USER"
chown "$TEST_USER" "/Users/$TEST_USER"

sysadminctl -deleteUser "$TEST_USER" 2>&1 || true
