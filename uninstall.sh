#!/usr/bin/env bash
# Usage: sudo ./uninstall.sh

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: uninstall.sh must be run with sudo." >&2
  exit 1
fi

REAL_USER="${SUDO_USER:?uninstall.sh must be run with sudo, not as root directly}"
REAL_HOME="$(eval echo "~${REAL_USER}")"

REAL_UID="$(id -u "$REAL_USER")"
rm -f "/etc/sudoers.d/pen-${REAL_UID}"
rm -f "${REAL_HOME}/.local/bin/pen"

echo "Uninstall complete."
