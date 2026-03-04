#!/usr/bin/env bash
# One-time dev machine setup for working on pen.
# Usage: sudo ./develop.sh [--undo]

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: develop.sh must be run with sudo." >&2
  exit 1
fi

REAL_USER="${SUDO_USER:?develop.sh must be run with sudo, not as root directly}"
PEN_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REAL_UID="$(id -u "$REAL_USER")"
SUDOERS_FILE="/etc/sudoers.d/pen-dev-${REAL_UID}"

if [[ "${1:-}" == "--undo" ]]; then
  rm -f "$SUDOERS_FILE"
  for script in test/run-e2e.sh test/e2e-setup.sh test/e2e-teardown.sh test/e2e-interactive.sh; do
    chown "$REAL_USER:staff" "${PEN_HOME}/${script}"
  done
  sudo -u "$REAL_USER" git -C "$PEN_HOME" config --unset core.hooksPath || true
  echo "Dev setup undone."
  exit 0
fi

echo "Installing runtime dependencies (brew bundle)..."
sudo -u "$REAL_USER" env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="${PEN_HOME}/Brewfile"

echo "Installing dev dependencies (brew bundle)..."
sudo -u "$REAL_USER" env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="${PEN_HOME}/Brewfile.dev"

echo "Setting ownership on test scripts..."
for script in test/run-e2e.sh test/e2e-setup.sh test/e2e-teardown.sh test/e2e-interactive.sh; do
  chown root:wheel "${PEN_HOME}/${script}"
  chmod 755 "${PEN_HOME}/${script}"
done

echo "Configuring sudoers for test scripts..."
cat > "$SUDOERS_FILE" <<EOF
${REAL_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/run-e2e.sh
${REAL_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-setup.sh
${REAL_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-teardown.sh
${REAL_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/e2e-interactive.sh
EOF
chmod 440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1

echo "Configuring git hooks..."
sudo -u "$REAL_USER" git -C "$PEN_HOME" config core.hooksPath .githooks

echo "Dev setup complete."
