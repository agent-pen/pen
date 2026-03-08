#!/usr/bin/env bash
# Run the e2e bats test suite as the test user in their Mach context.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-user-guard.sh"
require_root

TEST_USER="${1:?Usage: run-test-suite.sh <username>}"
PEN_REPO="/Users/$TEST_USER/pen-source"
readonly TEST_USER PEN_REPO

run_as_test_user "$TEST_USER" "$PEN_REPO/test/run.sh"
