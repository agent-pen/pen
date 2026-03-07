#!/usr/bin/env bash
# E2E teardown: delete test user and clean up.
# Usage: test/e2e-teardown.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

sudo "$SCRIPT_DIR/e2e-ops/delete-test-user.sh"

echo "Teardown complete."
