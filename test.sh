#!/usr/bin/env bash
# E2E test wrapper: setup → run → teardown.
# Usage: ./test.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

trap "$SCRIPT_DIR/test/e2e-teardown.sh" EXIT

"$SCRIPT_DIR/test/e2e-setup.sh"

sudo "$SCRIPT_DIR/test/e2e-ops/privileged/run-test-suite.sh"
