#!/usr/bin/env bash
# Test teardown: delete test user and clean up.
# Usage: test/teardown.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/ops/delete-test-user.sh"

echo "Teardown complete."
