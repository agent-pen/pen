#!/usr/bin/env bash
# Drop into an interactive login shell as the test user in their Mach context.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: must be run as root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-user-guard.sh"

TEST_USER="${1:?Usage: shell-test-user.sh <username>}"

run_as_test_user "$TEST_USER"
