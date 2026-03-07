#!/usr/bin/env bash
# E2E setup: create test user, configure environment.
# Usage: test/e2e-setup.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "Cleaning up any leftover test user..."
sudo "$SCRIPT_DIR/e2e-ops/delete-test-user.sh"

echo "Creating test user..."
sudo "$SCRIPT_DIR/e2e-ops/create-test-user.sh"

echo "Configuring test environment..."
sudo "$SCRIPT_DIR/e2e-ops/configure-test-env.sh"

echo ""
echo "Setup complete."
echo "To debug interactively:"
echo "  sudo $SCRIPT_DIR/e2e-ops/shell-test-user.sh"
