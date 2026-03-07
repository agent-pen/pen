#!/usr/bin/env bash
# Drop into an interactive login shell as the test user in their Mach context.
# Must be run as root.

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: must be run as root." >&2
  exit 1
fi

TEST_USER="pen-e2e-test-user"
TEST_UID="$(id -u "$TEST_USER")"

launchctl asuser "$TEST_UID" sudo -i -u "$TEST_USER"
