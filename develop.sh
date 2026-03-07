#!/usr/bin/env bash
# One-time dev machine setup for working on pen.
# Usage: ./develop.sh [--undo]

set -o nounset -o errexit -o pipefail

PEN_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER="$(whoami)"
CURRENT_UID="$(id -u)"
SUDOERS_FILE="/etc/sudoers.d/pen-dev-${CURRENT_UID}"

if [[ "${1:-}" == "--undo" ]]; then
  sudo rm -f "$SUDOERS_FILE"
  for script in test/e2e-ops/create-test-user.sh test/e2e-ops/delete-test-user.sh test/e2e-ops/configure-test-env.sh test/e2e-ops/run-test-suite.sh test/e2e-ops/shell-test-user.sh; do
    sudo chown "$CURRENT_USER:staff" "${PEN_HOME}/${script}"
  done
  git -C "$PEN_HOME" config --unset core.hooksPath || true
  echo "Dev setup undone."
  exit 0
fi

echo "Installing runtime dependencies (brew bundle)..."
env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="${PEN_HOME}/Brewfile"

echo "Installing dev dependencies (brew bundle)..."
env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="${PEN_HOME}/Brewfile.dev"

echo "Setting ownership on privileged test scripts..."
for script in test/e2e-ops/create-test-user.sh test/e2e-ops/delete-test-user.sh test/e2e-ops/configure-test-env.sh test/e2e-ops/run-test-suite.sh test/e2e-ops/shell-test-user.sh; do
  sudo chown root:wheel "${PEN_HOME}/${script}"
  sudo chmod 755 "${PEN_HOME}/${script}"
done

echo "Configuring sudoers for privileged test scripts..."
sudo tee "$SUDOERS_FILE" > /dev/null <<EOF
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/create-test-user.sh
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/delete-test-user.sh
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/configure-test-env.sh
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/run-test-suite.sh
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/shell-test-user.sh
EOF
sudo chmod 440 "$SUDOERS_FILE"
sudo visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1

echo "Configuring git hooks..."
git -C "$PEN_HOME" config core.hooksPath .githooks

echo "Dev setup complete."
