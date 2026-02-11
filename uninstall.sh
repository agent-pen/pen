#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

sudo rm -f /etc/sudoers.d/pen
sudo rm -f /usr/local/bin/pen

echo "Uninstall complete."
