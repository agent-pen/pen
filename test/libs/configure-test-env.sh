#!/usr/bin/env bash
# Configure the e2e test environment: copy container data, copy pen source,
# and grant privileges for the test user to run install/uninstall.
# Orchestrator — delegates to leaf scripts that run as root.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEST_USER="${1:?Usage: configure-test-env.sh <username>}"

sudo "$SCRIPT_DIR/privileged/copy-container-data.sh" "$TEST_USER"
sudo "$SCRIPT_DIR/privileged/copy-pen-source.sh" "$TEST_USER"
sudo "$SCRIPT_DIR/privileged/grant-test-privileges.sh" "$TEST_USER"

echo "Test environment configured."
