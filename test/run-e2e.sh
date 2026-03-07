#!/usr/bin/env bash
# E2E test wrapper: setup → run → teardown.
# Usage: test/run-e2e.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

trap "$SCRIPT_DIR/e2e-teardown.sh" EXIT

"$SCRIPT_DIR/e2e-setup.sh"

sudo "$SCRIPT_DIR/e2e-ops/run-test-suite.sh"
