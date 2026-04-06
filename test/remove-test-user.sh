#!/usr/bin/env bash
# Remove the e2e test user if it exists.
# Usage: test/remove-test-user.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/test.env"

PEN_TEST_FRESH_USER=1 "$SCRIPT_DIR/teardown.sh" "$TEST_USER"
