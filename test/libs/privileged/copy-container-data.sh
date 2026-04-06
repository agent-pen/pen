#!/usr/bin/env bash
# Copy container data (kernels + content) from invoking user to e2e test user.
# Fixes absolute symlinks and sets ownership.
# Must be run as root via sudo.

set -o nounset -o errexit -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/target-user-guards.sh"
require_root

TARGET="${1:?Usage: copy-container-data.sh <username>}"
ensure_correct_target_user_and_uid "$TARGET"

SUDO_USER_HOME="/Users/${SUDO_USER:?must be run via sudo}"
CONTAINER_BASE="Library/Application Support/com.apple.container"
SRC="$SUDO_USER_HOME/$CONTAINER_BASE"
DST="/Users/$TARGET/$CONTAINER_BASE"

ensure_correct_target_path "$DST"
readonly TARGET SUDO_USER_HOME CONTAINER_BASE SRC DST

mkdir -p "$DST"

if [[ -f "$SRC/state.json" ]]; then
  rsync -a "$SRC/state.json" "$DST/state.json"
fi

for subdir in kernels content; do
  if [[ -d "$SRC/$subdir" ]]; then
    rsync -a --delete "$SRC/$subdir/" "$DST/$subdir/"
    find "$DST/$subdir" -type l | while read -r link; do
      local_target="$(readlink "$link")"
      if [[ "$local_target" == "$SUDO_USER_HOME"* ]]; then
        ln -sf "${local_target/$SUDO_USER_HOME//Users/$TARGET}" "$link"
      fi
    done
  else
    echo "Warning: $SRC/$subdir not found — will be downloaded at runtime."
  fi
done

# Own the entire tree (including Library/Application Support intermediates)
# so `container system start` can create the apiserver socket.
chown -R "$TARGET:staff" "/Users/$TARGET/Library"
