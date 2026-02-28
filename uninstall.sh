#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

sudo rm -f "/etc/sudoers.d/pen-$(whoami)"
rm -f "${HOME}/.local/bin/pen"

echo "Uninstall complete."
