#!/usr/bin/env bash
# Run the e2e bats test suite as the test user in their Mach context.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: must be run as root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-user-guard.sh"

TEST_USER="pen-e2e-test-user"
PEN_REPO="/Users/$TEST_USER/pen-source"

run_as_test_user "$TEST_USER" "$PEN_REPO/test/e2e-run.sh"
