#!/usr/bin/env bash
# Test teardown: delete test user and clean up.
# Usage: test/teardown.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEST_USER="${1:?Usage: test/teardown.sh <username>}"

"$SCRIPT_DIR/libs/delete-test-user.sh" "$TEST_USER"

echo "Teardown complete."
