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
  chown "$REAL_USER:staff" "${PEN_HOME}/test/run-e2e.sh"
  sudo -u "$REAL_USER" git -C "$PEN_HOME" config --unset core.hooksPath || true
  echo "Dev setup undone."
  exit 0
fi

sudo -u "$REAL_USER" env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="${PEN_HOME}/Brewfile"
sudo -u "$REAL_USER" env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="${PEN_HOME}/Brewfile.dev"

chown root:wheel "${PEN_HOME}/test/run-e2e.sh"
chmod 755 "${PEN_HOME}/test/run-e2e.sh"

sudoers_line="${REAL_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/run-e2e.sh"
echo "$sudoers_line" | tee "$SUDOERS_FILE" > /dev/null
chmod 440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1

sudo -u "$REAL_USER" git -C "$PEN_HOME" config core.hooksPath .githooks

echo "Dev setup complete."
