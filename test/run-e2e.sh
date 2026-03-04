#!/usr/bin/env bash
# E2E test wrapper: setup → run → teardown.
# Usage: sudo test/run-e2e.sh

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: run-e2e.sh must be run as root (use sudo)." >&2
  exit 1
fi

PEN_REPO_SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

TEST_USER="pen-e2e-test-user"

trap "$PEN_REPO_SRC/test/e2e-teardown.sh" EXIT

"$PEN_REPO_SRC/test/e2e-setup.sh"

TEST_UID="$(id -u "$TEST_USER")"
PEN_REPO="/Users/$TEST_USER/pen-source"
sudo launchctl asuser "$TEST_UID" sudo -i -u "$TEST_USER" "$PEN_REPO/test/e2e-run.sh"
