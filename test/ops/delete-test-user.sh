#!/usr/bin/env bash
# Delete the e2e test user and clean up sudoers and launchd state.
# Orchestrator — delegates to leaf scripts that run as root.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEST_USER="pen-test-user"

if ! id "$TEST_USER" &>/dev/null; then
  exit 0
fi

sudo "$SCRIPT_DIR/privileged/remove-test-sudoers.sh" "$TEST_USER"
sudo "$SCRIPT_DIR/privileged/delete-test-account.sh" "$TEST_USER"
