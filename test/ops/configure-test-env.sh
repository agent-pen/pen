#!/usr/bin/env bash
# Configure the e2e test environment: copy container data, start apiserver,
# copy pen source, and add scoped sudoers for the test user.
# Orchestrator — delegates to leaf scripts that run as root.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PEN_REPO_SRC="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
TEST_USER="pen-e2e-test-user"

sudo "$SCRIPT_DIR/privileged/copy-container-data.sh" "$TEST_USER"
sudo "$SCRIPT_DIR/privileged/start-test-apiserver.sh" "$TEST_USER"
sudo "$SCRIPT_DIR/privileged/copy-pen-source.sh" "$PEN_REPO_SRC" "$TEST_USER"
sudo "$SCRIPT_DIR/privileged/add-test-sudoers.sh" "$TEST_USER" "/Users/$TEST_USER/pen-source"

echo "Test environment configured."
