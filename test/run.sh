#!/usr/bin/env bash
# Run bats tests. Must run as the test user inside their Mach context.
# Usage: called by run-test-suite.sh or manually via launchctl asuser

set -o nounset -o errexit -o pipefail

export PEN_REPO="$HOME/pen-source"
exec bats "$PEN_REPO/test/suite/"
