#!/usr/bin/env bash
# Usage: sudo ./install.sh

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: install.sh must be run with sudo." >&2
  exit 1
fi

REAL_USER="${SUDO_USER:?install.sh must be run with sudo, not as root directly}"
REAL_HOME="$(eval echo "~${REAL_USER}")"

PEN_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PFCTL_WRAPPER="${PEN_HOME}/penctl/commands/lib/pfctl-wrapper.sh"
SUDOERS_FILE="/etc/sudoers.d/pen-${REAL_USER}"
LOCAL_BIN="${REAL_HOME}/.local/bin"

# Symlink pen into per-user PATH
sudo -u "$REAL_USER" mkdir -p "$LOCAL_BIN"
sudo -u "$REAL_USER" ln -sf "${PEN_HOME}/pen" "${LOCAL_BIN}/pen"

if ! sudo -u "$REAL_USER" bash -c '[[ ":${PATH}:" == *":'"$LOCAL_BIN"':"* ]]'; then
  echo "Warning: ${LOCAL_BIN} is not on your PATH."
  echo "Add it to your shell profile, e.g.:"
  echo "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
fi

# pfctl wrapper must be owned by root for secure sudo execution
chown root:wheel "$PFCTL_WRAPPER"
chmod 755 "$PFCTL_WRAPPER"

# Per-user sudoers entry for the pfctl wrapper
sudoers_line="${REAL_USER} ALL=(root) NOPASSWD: ${PFCTL_WRAPPER}"
echo "$sudoers_line" | tee "$SUDOERS_FILE" > /dev/null
chmod 440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1

sudo -u "$REAL_USER" mkdir -p "${REAL_HOME}/.pen/sandboxes"

echo "Installation succeeded."
