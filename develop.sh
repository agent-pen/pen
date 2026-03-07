#!/usr/bin/env bash
# One-time dev machine setup for working on pen.
# Usage: ./develop.sh [--undo]

set -o nounset -o errexit -o pipefail

PEN_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER="$(whoami)"
CURRENT_UID="$(id -u)"
SUDOERS_FILE="/etc/sudoers.d/pen-dev-${CURRENT_UID}"

UNDO="${1:-}"

PRIVILEGED_SCRIPTS=(
  test/e2e-ops/test-user-guard.sh
  test/e2e-ops/create-test-user.sh
  test/e2e-ops/run-test-suite.sh
  test/e2e-ops/shell-test-user.sh
  test/e2e-ops/remove-test-sudoers.sh
  test/e2e-ops/delete-test-account.sh
  test/e2e-ops/copy-container-data.sh
  test/e2e-ops/start-test-apiserver.sh
  test/e2e-ops/copy-pen-source.sh
  test/e2e-ops/add-test-sudoers.sh
)

if [[ "$UNDO" == "--undo" ]]; then
  echo "Removing sudoers for privileged test scripts..."
  sudo rm -f "$SUDOERS_FILE"
else
  echo "Configuring sudoers for privileged test scripts..."
  sudo tee "$SUDOERS_FILE" > /dev/null <<EOF
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/create-test-user.sh
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/run-test-suite.sh
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/shell-test-user.sh
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/remove-test-sudoers.sh *
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/delete-test-account.sh *
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/copy-container-data.sh *
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/start-test-apiserver.sh *
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/copy-pen-source.sh * *
${CURRENT_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-ops/add-test-sudoers.sh * *
EOF
  sudo chmod 440 "$SUDOERS_FILE"
  sudo visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1
fi

if [[ "$UNDO" == "--undo" ]]; then
  echo "Resetting ownership on privileged test scripts..."
  for script in "${PRIVILEGED_SCRIPTS[@]}"; do
    sudo chown "$CURRENT_USER:staff" "${PEN_HOME}/${script}"
  done
else
  echo "Setting ownership on privileged test scripts..."
  for script in "${PRIVILEGED_SCRIPTS[@]}"; do
    sudo chown root:wheel "${PEN_HOME}/${script}"
    sudo chmod 755 "${PEN_HOME}/${script}"
  done
fi

if [[ "$UNDO" == "--undo" ]]; then
  echo "Removing git hooks..."
  git -C "$PEN_HOME" config --unset core.hooksPath || true
else
  echo "Configuring git hooks..."
  git -C "$PEN_HOME" config core.hooksPath .githooks
fi

if [[ "$UNDO" != "--undo" ]]; then
  echo "Installing runtime dependencies (brew bundle)..."
  env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="${PEN_HOME}/Brewfile"

  echo "Installing dev dependencies (brew bundle)..."
  env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="${PEN_HOME}/Brewfile.dev"
fi

if [[ "$UNDO" == "--undo" ]]; then
  echo "Dev setup undone."
else
  echo "Dev setup complete."
fi
