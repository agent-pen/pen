#!/usr/bin/env bash
# E2E teardown: delete test user and clean up.
# Usage: sudo test/e2e-teardown.sh

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: e2e-teardown.sh must be run as root (use sudo)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/e2e-lib.sh"

delete_test_user

echo "Teardown complete."
