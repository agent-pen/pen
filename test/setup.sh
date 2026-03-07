#!/usr/bin/env bash
# Test setup: create test user, configure environment.
# Usage: test/setup.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "Cleaning up any leftover test user..."
"$SCRIPT_DIR/ops/delete-test-user.sh"

echo "Creating test user..."
sudo "$SCRIPT_DIR/ops/privileged/create-test-user.sh"

echo "Configuring test environment..."
"$SCRIPT_DIR/ops/configure-test-env.sh"

echo ""
echo "Setup complete."
echo "To debug interactively:"
echo "  sudo $SCRIPT_DIR/ops/privileged/shell-test-user.sh"
