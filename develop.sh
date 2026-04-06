#!/usr/bin/env bash
# One-time dev machine setup for working on pen.
# Usage: ./develop.sh [--undo]

set -o nounset -o errexit -o pipefail

PEN_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER="$(whoami)"
CURRENT_UID="$(id -u)"
SUDOERS_FILE="/etc/sudoers.d/pen-dev-${CURRENT_UID}"

UNDO="${1:-}"
PRIVILEGED_DIR="${PEN_HOME}/test/libs/privileged"
# Explicit list — new scripts must be added here to get sudoers grants.
# target-user-guards.sh is excluded: it's a library sourced by these scripts,
# not a command, so it needs root ownership (below) but not a sudoers entry.
PRIVILEGED_SCRIPTS=(
  "${PRIVILEGED_DIR}/clean-test-user-processes.sh"
  "${PRIVILEGED_DIR}/copy-container-data.sh"
  "${PRIVILEGED_DIR}/copy-pen-source.sh"
  "${PRIVILEGED_DIR}/create-test-user.sh"
  "${PRIVILEGED_DIR}/delete-test-account.sh"
  "${PRIVILEGED_DIR}/grant-test-privileges.sh"
  "${PRIVILEGED_DIR}/remove-test-sudoers.sh"
  "${PRIVILEGED_DIR}/run-test-suite.sh"
  "${PRIVILEGED_DIR}/shell-test-user.sh"
)
readonly PRIVILEGED_SCRIPTS

if [[ "$UNDO" == "--undo" ]]; then
  echo "Removing sudoers for privileged test scripts..."
  sudo rm -f "$SUDOERS_FILE"
else
  echo "Configuring sudoers for privileged test scripts..."
  sudoers_lines=""
  for script in "${PRIVILEGED_SCRIPTS[@]}"; do
    if [[ ! -f "$script" ]]; then
      echo "FATAL: expected script not found: $script" >&2
      exit 1
    fi
    sudoers_lines+="${CURRENT_USER} ALL=(root) NOPASSWD: ${script} *"$'\n'
  done
  echo "$sudoers_lines" | sudo tee "$SUDOERS_FILE" > /dev/null
  sudo chmod 440 "$SUDOERS_FILE"
  sudo visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1
fi

if [[ "$UNDO" == "--undo" ]]; then
  echo "Resetting ownership on privileged test scripts..."
  for script in "${PRIVILEGED_SCRIPTS[@]}" "${PRIVILEGED_DIR}/target-user-guards.sh"; do
    sudo chown "$CURRENT_USER:staff" "$script"
  done
else
  echo "Setting ownership on privileged test scripts..."
  for script in "${PRIVILEGED_SCRIPTS[@]}" "${PRIVILEGED_DIR}/target-user-guards.sh"; do
    sudo chown root:wheel "$script"
    sudo chmod 755 "$script"
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

if [[ "$UNDO" != "--undo" ]]; then
  echo "Building test-minimal container image..."
  container system start --enable-kernel-install
  container build -t pen-test-minimal --file "${PEN_HOME}/test/suite/fixtures/Dockerfile.test-minimal-build" "${PEN_HOME}/test/suite/fixtures"
fi

if [[ "$UNDO" == "--undo" ]]; then
  echo "Dev setup undone."
else
  echo ""
  echo "Dev setup complete."
  echo ""
  echo "Manual step required:"
  echo "  Grant your terminal app Full Disk Access in"
  echo "  System Settings > Privacy & Security > Full Disk Access."
  echo "  Without this, sysadminctl triggers a GUI dialog during tests."
fi
