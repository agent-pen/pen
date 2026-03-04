#!/usr/bin/env bash
# E2E setup: create test user, copy data, add scoped sudoers, start apiserver.
# Usage: sudo test/e2e-setup.sh

set -o nounset -o errexit -o pipefail

TEST_USER="pen-e2e-test-user"
PEN_REPO_SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: e2e-setup.sh must be run as root (use sudo)." >&2
    exit 1
  fi
}

delete_leftover_test_user() {
  if id "$TEST_USER" &>/dev/null; then
    echo "Cleaning up leftover test user..."
    rm -f "/etc/sudoers.d/pen-$(id -u "$TEST_USER")-e2e-test"
    rm -f "/etc/sudoers.d/pen-$(id -u "$TEST_USER")"
    sysadminctl -deleteUser "$TEST_USER" 2>&1 || true
  fi
}

create_test_user() {
  local password
  password="$(openssl rand -hex 16)"

  # FDE (FileVault) warning is expected — suppressing it requires admin credentials
  # which we don't have non-interactively. The test user doesn't need FDE.
  sysadminctl -addUser "$TEST_USER" \
    -fullName "pen test user" \
    -password "$password" \
    -home "/Users/$TEST_USER" 2>&1

  # sysadminctl -createHomeDirectory is broken — use createhomedir instead.
  createhomedir -c -u "$TEST_USER" 2>&1

  TEST_UID="$(id -u "$TEST_USER")"
  PEN_REPO_DEST="/Users/$TEST_USER/pen-source"
  TEST_PROJECT="/Users/$TEST_USER/test-project"
}

copy_container_data() {
  local container_base="Library/Application Support/com.apple.container"
  local sudo_user_home
  sudo_user_home="$(eval echo "~${SUDO_USER}")"
  local src="$sudo_user_home/$container_base"
  local dst="/Users/$TEST_USER/$container_base"

  for subdir in kernels content; do
    if [[ -d "$src/$subdir" ]]; then
      sudo -u "$TEST_USER" mkdir -p "$dst/$subdir"
      cp -R "$src/$subdir"/* "$dst/$subdir"/
      find "$dst/$subdir" -type l | while read -r link; do
        local target
        target="$(readlink "$link")"
        if [[ "$target" == "$sudo_user_home"* ]]; then
          ln -sf "${target/$sudo_user_home//Users/$TEST_USER}" "$link"
        fi
      done
      chown -R "$TEST_USER:staff" "$dst/$subdir"
    else
      echo "Warning: $src/$subdir not found — will be downloaded at runtime."
    fi
  done
}

start_container_apiserver() {
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

require_root
delete_leftover_test_user
create_test_user
copy_container_data
start_container_apiserver
copy_pen_source
add_test_sudoers

echo ""
echo "Setup complete."
echo "To debug interactively:"
echo "  sudo launchctl asuser $TEST_UID sudo -i -u $TEST_USER"
