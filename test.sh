#!/usr/bin/env bash
# Test wrapper: setup → run → teardown.
# Usage: ./test.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/test/test.env"

trap "$SCRIPT_DIR/test/teardown.sh $TEST_USER" EXIT

"$SCRIPT_DIR/test/setup.sh" "$TEST_USER"
sudo "$SCRIPT_DIR/test/ops/privileged/run-test-suite.sh" "$TEST_USER"
