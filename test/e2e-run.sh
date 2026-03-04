#!/usr/bin/env bash
# E2E run: execute bats tests. Must run as the test user inside their Mach context.
# Usage: called by run-e2e.sh or manually via launchctl asuser

set -o nounset -o errexit -o pipefail

export PEN_REPO="$HOME/pen-source"
export TEST_PROJECT="$HOME/test-project"
export PATH="$HOME/.local/bin:$PATH"

exec bats "$PEN_REPO/test/e2e/"
