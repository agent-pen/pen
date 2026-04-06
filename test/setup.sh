#!/usr/bin/env bash
# Test setup: ensure clean state, create test user if needed, configure environment.
# Usage: test/setup.sh <username>

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEST_USER="${1:?Usage: test/setup.sh <username>}"

"$SCRIPT_DIR/teardown.sh" "$TEST_USER"

if ! id "$TEST_USER" &>/dev/null; then
  echo "Creating test user..."
  sudo "$SCRIPT_DIR/libs/privileged/create-test-user.sh" "$TEST_USER"
  sudo "$SCRIPT_DIR/libs/privileged/copy-container-data.sh" "$TEST_USER"
fi

echo "Configuring test environment..."
"$SCRIPT_DIR/libs/configure-test-env.sh" "$TEST_USER"

echo ""
echo "Setup complete."
echo "To debug interactively:"
echo "  sudo $SCRIPT_DIR/libs/privileged/shell-test-user.sh $TEST_USER"
