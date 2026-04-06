#!/usr/bin/env bash
# Test teardown: clean up test user state and optionally delete the account.
# Set PEN_TEST_FRESH_USER=1 to delete the account (default: retain).
# Usage: test/teardown.sh <username>

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEST_USER="${1:?Usage: test/teardown.sh <username>}"

if ! id "$TEST_USER" &>/dev/null; then
  exit 0
fi

sudo "$SCRIPT_DIR/libs/privileged/remove-test-sudoers.sh" "$TEST_USER"

if [[ "${PEN_TEST_FRESH_USER:-}" == "1" ]]; then
  sudo "$SCRIPT_DIR/libs/privileged/delete-test-account.sh" "$TEST_USER"
fi

echo "Teardown complete."
