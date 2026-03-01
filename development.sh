#!/usr/bin/env bash
# One-time dev machine setup for working on pen.
# Usage: sudo ./development.sh

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: development.sh must be run with sudo." >&2
  exit 1
fi

REAL_USER="${SUDO_USER:?development.sh must be run with sudo, not as root directly}"
PEN_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

sudo -u "$REAL_USER" env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="${PEN_HOME}/Brewfile"
sudo -u "$REAL_USER" env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="${PEN_HOME}/Brewfile.dev"

chown root:wheel "${PEN_HOME}/test/run-e2e.sh"
chmod 755 "${PEN_HOME}/test/run-e2e.sh"

SUDOERS_FILE="/etc/sudoers.d/pen-dev-${REAL_USER//./_}"
sudoers_line="${REAL_USER} ALL=(root) NOPASSWD: ${PEN_HOME}/test/run-e2e.sh"
echo "$sudoers_line" | tee "$SUDOERS_FILE" > /dev/null
chmod 440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1

echo "Dev setup complete."
