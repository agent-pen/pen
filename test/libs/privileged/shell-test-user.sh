#!/usr/bin/env bash
# Drop into an interactive login shell as the test user in their Mach context.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/target-user-guards.sh"
require_root

TEST_USER="${1:?Usage: shell-test-user.sh <username>}"

run_as_test_user "$TEST_USER"
