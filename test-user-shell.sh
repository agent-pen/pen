#!/usr/bin/env bash
# Interactive e2e debugging session: setup, shell into test user, teardown on exit.
# Usage: ./test-user-shell.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/test/test.env"

trap "$SCRIPT_DIR/test/teardown.sh $TEST_USER" EXIT

"$SCRIPT_DIR/test/setup.sh" "$TEST_USER"

echo ""
echo "Entering interactive session as $TEST_USER. Exit the shell to tear down."
echo ""

sudo "$SCRIPT_DIR/test/libs/privileged/shell-test-user.sh" "$TEST_USER" || true
