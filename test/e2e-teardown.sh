#!/usr/bin/env bash
# E2E teardown: delete test user and clean up.
# Usage: sudo test/e2e-teardown.sh

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: e2e-teardown.sh must be run as root (use sudo)." >&2
  exit 1
fi

TEST_USER="pen-e2e-test-user"

# Derive UID from the user if they exist; sudoers cleanup needs it
if id "$TEST_USER" &>/dev/null; then
  TEST_UID="$(id -u "$TEST_USER")"

  rm -f "/etc/sudoers.d/pen-${TEST_UID}-e2e-test"
  rm -f "/etc/sudoers.d/pen-${TEST_UID}"

  sysadminctl -deleteUser "$TEST_USER" 2>&1 || true
fi

echo "Teardown complete."
