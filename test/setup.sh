#!/usr/bin/env bash
# Test setup: create test user, configure environment.
# Usage: test/setup.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEST_USER="${1:?Usage: test/setup.sh <username>}"

echo "Cleaning up any leftover test user..."
"$SCRIPT_DIR/ops/delete-test-user.sh" "$TEST_USER"

echo "Creating test user..."
sudo "$SCRIPT_DIR/ops/privileged/create-test-user.sh" "$TEST_USER"

echo "Configuring test environment..."
"$SCRIPT_DIR/ops/configure-test-env.sh" "$TEST_USER"

echo ""
echo "Setup complete."
echo "To debug interactively:"
echo "  sudo $SCRIPT_DIR/ops/privileged/shell-test-user.sh $TEST_USER"
