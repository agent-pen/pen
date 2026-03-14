#!/usr/bin/env bash
# Usage: sudo ./install.sh

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: install.sh must be run with sudo." >&2
  exit 1
fi

REAL_USER="${SUDO_USER:?install.sh must be run with sudo, not as root directly}"
REAL_HOME="/Users/${REAL_USER}"
if [[ ! -d "$REAL_HOME" ]]; then
  echo "Error: home directory not found: $REAL_HOME" >&2
  exit 1
fi

PEN_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PFCTL_WRAPPER="${PEN_HOME}/penctl/commands/lib/pfctl-wrapper.sh"
REAL_UID="$(id -u "$REAL_USER")"
SUDOERS_FILE="/etc/sudoers.d/pen-${REAL_UID}"
LOCAL_BIN="${REAL_HOME}/.local/bin"

symlink_pen_binary() {
  sudo -u "$REAL_USER" mkdir -p "$LOCAL_BIN"
  sudo -u "$REAL_USER" ln -sf "${PEN_HOME}/pen" "${LOCAL_BIN}/pen"

  if ! sudo -u "$REAL_USER" bash -c '[[ ":${PATH}:" == *":'"$LOCAL_BIN"':"* ]]'; then
    echo "Warning: ${LOCAL_BIN} is not on your PATH."
    echo "Add it to your shell profile, e.g.:"
    echo "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
  fi
}

secure_pfctl_wrapper() {
  chown root:wheel "$PFCTL_WRAPPER"
  chmod 755 "$PFCTL_WRAPPER"
}

write_sudoers_entry() {
  local sudoers_line="${REAL_USER} ALL=(root) NOPASSWD: ${PFCTL_WRAPPER}"
  echo "$sudoers_line" | tee "$SUDOERS_FILE" > /dev/null
  chmod 440 "$SUDOERS_FILE"
  visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1
}

create_pen_home() {
  sudo -u "$REAL_USER" mkdir -p "${REAL_HOME}/.pen/sandboxes"
}

symlink_pen_binary
secure_pfctl_wrapper
write_sudoers_entry
create_pen_home

echo "Installation succeeded."
