#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

PEN_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PFCTL_WRAPPER="${PEN_HOME}/penctl/commands/lib/pfctl-wrapper.sh"
SUDOERS_FILE="/etc/sudoers.d/pen"

sudo ln -sf "${PEN_HOME}/pen" /usr/local/bin/pen

sudo chown root:wheel "$PFCTL_WRAPPER"
sudo chmod 755 "$PFCTL_WRAPPER"

sudoers_line="$(whoami) ALL=(root) NOPASSWD: ${PFCTL_WRAPPER}"
echo "$sudoers_line" | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 440 "$SUDOERS_FILE"
sudo visudo -cf "$SUDOERS_FILE" > /dev/null 2>&1

mkdir -p "${HOME}/.pen/sandboxes"

echo "Installation succeeded."
