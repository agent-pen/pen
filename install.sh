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

install_pfctl_wrapper() {
  local pen_home="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  local pfctl_wrapper="${pen_home}/penctl/commands/lib/pfctl-wrapper.sh"
  chown root:wheel "$pfctl_wrapper"
  chmod 755 "$pfctl_wrapper"

  local real_uid="$(id -u "$REAL_USER")"
  local sudoers_file="/etc/sudoers.d/pen-${real_uid}"
  local sudoers_line="${REAL_USER} ALL=(root) NOPASSWD: ${pfctl_wrapper}"
  echo "$sudoers_line" | visudo -cf /dev/stdin > /dev/null
  echo "$sudoers_line" > "$sudoers_file"
  chmod 440 "$sudoers_file"
}

create_pen_home() {
  sudo -u "$REAL_USER" mkdir -p "${REAL_HOME}/.pen/sandboxes"
}

symlink_pen_binary() {
  local pen_home="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  local local_bin="${REAL_HOME}/.local/bin"
  sudo -u "$REAL_USER" mkdir -p "$local_bin"
  sudo -u "$REAL_USER" ln -sf "${pen_home}/pen" "${local_bin}/pen"

  echo "Ensure ~/.local/bin is on your PATH. Add to ~/.zshrc, ~/.bashrc, etc.:"
  echo "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
}

install_pfctl_wrapper
create_pen_home
symlink_pen_binary

echo ""
echo "Installation succeeded."
