#!/usr/bin/env bash
# Interactive e2e debugging session: setup, shell into test user, teardown on exit.
# Usage: test/e2e-interactive.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/e2e-setup.sh"

echo ""
echo "Entering interactive session as pen-e2e-test-user. Exit the shell to tear down."
echo ""

sudo "$SCRIPT_DIR/e2e-ops/privileged/shell-test-user.sh" || true

"$SCRIPT_DIR/e2e-teardown.sh"
