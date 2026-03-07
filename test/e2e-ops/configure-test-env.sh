#!/usr/bin/env bash
# Configure the e2e test environment: copy container data, start apiserver,
# copy pen source, and add scoped sudoers for the test user.
# Must be run as root via sudo (uses $SUDO_USER for container data source).

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: must be run as root." >&2
  exit 1
fi

TEST_USER="pen-e2e-test-user"
TEST_UID="$(id -u "$TEST_USER")"
SUDO_USER_HOME="$(eval echo "~${SUDO_USER:?must be run via sudo}")"
PEN_REPO_SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PEN_REPO_DEST="/Users/$TEST_USER/pen-source"
TEST_PROJECT="/Users/$TEST_USER/test-project"

copy_container_data() {
  local container_base="Library/Application Support/com.apple.container"
  local src="$SUDO_USER_HOME/$container_base"
  local dst="/Users/$TEST_USER/$container_base"

  for subdir in kernels content; do
    if [[ -d "$src/$subdir" ]]; then
      sudo -u "$TEST_USER" mkdir -p "$dst/$subdir"
      cp -R "$src/$subdir"/* "$dst/$subdir"/
      find "$dst/$subdir" -type l | while read -r link; do
        local target
        target="$(readlink "$link")"
        if [[ "$target" == "$SUDO_USER_HOME"* ]]; then
          ln -sf "${target/$SUDO_USER_HOME//Users/$TEST_USER}" "$link"
        fi
      done
      chown -R "$TEST_USER:staff" "$dst/$subdir"
    else
      echo "Warning: $src/$subdir not found — will be downloaded at runtime."
    fi
  done
}

start_container_apiserver() {
  # Restart to clear any stale networking state (e.g. pending network operations)
  # left over from a previous test user with the same name.
  launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" container system stop 2>/dev/null || true
  launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" container system start

  echo "Waiting for container apiserver to be ready..."
  local attempts=0
  while ! launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" container image list &>/dev/null; do
    attempts=$((attempts + 1))
    if [[ "$attempts" -ge 30 ]]; then
      echo "Error: container apiserver did not become ready after 30 seconds" >&2
      exit 1
    fi
    sleep 1
  done
  echo "Container apiserver is ready."
}

copy_pen_source() {
  cp -R "$PEN_REPO_SRC" "$PEN_REPO_DEST"
  chown -R "$TEST_USER:staff" "$PEN_REPO_DEST"
  sudo -u "$TEST_USER" mkdir -p "$TEST_PROJECT"
}

add_test_sudoers() {
  local sudoers_file="/etc/sudoers.d/pen-${TEST_UID}-e2e-test"
  cat > "$sudoers_file" <<EOF
$TEST_USER ALL=(root) NOPASSWD: $PEN_REPO_DEST/install.sh
$TEST_USER ALL=(root) NOPASSWD: $PEN_REPO_DEST/uninstall.sh
EOF
  chmod 440 "$sudoers_file"
  visudo -cf "$sudoers_file" > /dev/null 2>&1
}

# --- Main ---

copy_container_data
start_container_apiserver
copy_pen_source
add_test_sudoers

echo "Test environment configured."
