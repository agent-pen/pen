#!/usr/bin/env bash
# One-time dev machine setup for working on pen.
# Usage: ./develop.sh [--undo]

set -o nounset -o errexit -o pipefail

PEN_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER="$(whoami)"
CURRENT_UID="$(id -u)"
SUDOERS_FILE="/etc/sudoers.d/pen-dev-${CURRENT_UID}"

UNDO="${1:-}"
PRIVILEGED_DIR="${PEN_HOME}/test/ops/privileged"

if [[ "$UNDO" == "--undo" ]]; then
  echo "Removing sudoers for privileged test scripts..."
  sudo rm -f "$SUDOERS_FILE"
else
  echo "Configuring sudoers for privileged test scripts..."
  sudoers_lines=""
  for script in "$PRIVILEGED_DIR"/*.sh; do
    sudoers_lines+="${CURRENT_USER} ALL=(root) NOPASSWD: ${script} *"$'\n'
  done
  echo "$sudoers_lines" | sudo tee "$SUDOERS_FILE" > /dev/null
  sudo chmod 440 "$SUDOERS_FILE"
  sudo visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1
fi

if [[ "$UNDO" == "--undo" ]]; then
  echo "Resetting ownership on privileged test scripts..."
  for script in "$PRIVILEGED_DIR"/*.sh; do
    sudo chown "$CURRENT_USER:staff" "$script"
  done
else
  echo "Setting ownership on privileged test scripts..."
  for script in "$PRIVILEGED_DIR"/*.sh; do
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

if [[ "$UNDO" == "--undo" ]]; then
  echo "Dev setup undone."
else
  echo "Dev setup complete."
fi
