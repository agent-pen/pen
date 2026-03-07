#!/usr/bin/env bash
# Start the container apiserver as the e2e test user.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: must be run as root." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-user-guard.sh"

TARGET="${1:?Usage: start-test-apiserver.sh <username>}"
readonly TARGET

# Restart to clear any stale networking state (e.g. pending network operations)
# left over from a previous test user with the same name.
run_as_test_user "$TARGET" container system stop 2>/dev/null || true
run_as_test_user "$TARGET" container system start

echo "Waiting for container apiserver to be ready..."
attempts=0
while ! run_as_test_user "$TARGET" container image list &>/dev/null; do
  attempts=$((attempts + 1))
  if [[ "$attempts" -ge 30 ]]; then
    echo "Error: container apiserver did not become ready after 30 seconds" >&2
    exit 1
  fi
  sleep 1
done
echo "Container apiserver is ready."
