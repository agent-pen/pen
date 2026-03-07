#!/usr/bin/env bash
# Test wrapper: setup → run → teardown.
# Usage: ./test.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

trap "$SCRIPT_DIR/test/teardown.sh" EXIT

"$SCRIPT_DIR/test/setup.sh"

sudo "$SCRIPT_DIR/test/ops/privileged/run-test-suite.sh"
