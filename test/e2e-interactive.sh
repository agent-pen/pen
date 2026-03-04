#!/usr/bin/env bash
# Interactive e2e debugging session: setup, shell into test user, teardown on exit.
# Usage: sudo test/e2e-interactive.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/e2e-setup.sh"

TEST_USER="pen-e2e-test-user"
TEST_UID="$(id -u "$TEST_USER")"

echo ""
echo "Entering interactive session as $TEST_USER. Exit the shell to tear down."
echo ""

launchctl asuser "$TEST_UID" sudo -i -u "$TEST_USER" || true

"$SCRIPT_DIR/e2e-teardown.sh"
