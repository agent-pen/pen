#!/usr/bin/env bash
# Test wrapper: setup → run → teardown.
# Usage: ./test.sh

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/test/test.env"

# --- Lock file: prevent concurrent test runs ---
LOCK_FILE="$SCRIPT_DIR/test/.lock"

if [ -f "$LOCK_FILE" ]; then
    existing_pid=$(cat "$LOCK_FILE")
    if kill -0 "$existing_pid" 2>/dev/null; then
        echo "ERROR: Another test run is already in progress (PID $existing_pid)." >&2
        echo "If this is stale, remove $LOCK_FILE and retry." >&2
        exit 1
    fi
    echo "Removing stale lock file (PID $existing_pid no longer running)."
    rm -f "$LOCK_FILE"
fi

echo $$ > "$LOCK_FILE"

cleanup() {
    rm -f "$LOCK_FILE"
    "$SCRIPT_DIR/test/teardown.sh" "$TEST_USER"
}
trap cleanup EXIT

"$SCRIPT_DIR/test/setup.sh" "$TEST_USER"
sudo "$SCRIPT_DIR/test/libs/privileged/run-test-suite.sh" "$TEST_USER"
