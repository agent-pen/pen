#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

PEN_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PFCTL_WRAPPER="${PEN_HOME}/penctl/commands/lib/pfctl-wrapper.sh"
SUDOERS_FILE="/etc/sudoers.d/pen-$(whoami)"
LOCAL_BIN="${HOME}/.local/bin"

# Symlink pen into per-user PATH (no sudo needed)
mkdir -p "$LOCAL_BIN"
ln -sf "${PEN_HOME}/pen" "${LOCAL_BIN}/pen"

if [[ ":${PATH}:" != *":${LOCAL_BIN}:"* ]]; then
  echo "Warning: ${LOCAL_BIN} is not on your PATH."
  echo "Add it to your shell profile, e.g.:"
  echo "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
fi

# pfctl wrapper must be owned by root for secure sudo execution
sudo chown root:wheel "$PFCTL_WRAPPER"
sudo chmod 755 "$PFCTL_WRAPPER"

# Per-user sudoers entry for the pfctl wrapper
sudoers_line="$(whoami) ALL=(root) NOPASSWD: ${PFCTL_WRAPPER}"
echo "$sudoers_line" | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 440 "$SUDOERS_FILE"
sudo visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1

mkdir -p "${HOME}/.pen/sandboxes"

echo "Installation succeeded."
