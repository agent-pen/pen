#!/usr/bin/env bash
# E2E test orchestrator. Creates a temporary macOS user, runs bats tests, tears down.
# Usage: sudo test/run-e2e.sh

set -o nounset -o errexit -o pipefail

TEST_USER="pen-e2e-test-user"
TEST_PASSWORD="$(openssl rand -hex 16)"
PEN_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: run-e2e.sh must be run as root (use sudo)." >&2
    exit 1
  fi
}

delete_test_user() {
  if id "$TEST_USER" &>/dev/null; then
    rm -f "/etc/sudoers.d/pen-$(id -u "$TEST_USER")"
  fi

  if id "$TEST_USER" &>/dev/null; then
    sysadminctl -deleteUser "$TEST_USER" 2>&1 || true
  fi
}

create_test_user() {
  # FDE (FileVault) warning is expected — suppressing it requires admin credentials
  # which we don't have non-interactively. The test user doesn't need FDE.
  sysadminctl -addUser "$TEST_USER" \
    -fullName "pen test user" \
    -password "$TEST_PASSWORD" \
    -home "/Users/$TEST_USER" 2>&1

  # sysadminctl's -createHomeDirectory flag is broken — it logs
  # "Home directory is assigned (not created!)" and doesn't create it.
  # createhomedir works reliably.
  createhomedir -c -u "$TEST_USER" 2>&1
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
      # Fix symlinks that contain absolute paths to the source user's home
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
  local test_uid
  test_uid="$(id -u "$TEST_USER")"
  launchctl asuser "$test_uid" sudo -u "$TEST_USER" container system start

  echo "Waiting for container apiserver to be ready..."
  local attempts=0
  while ! launchctl asuser "$test_uid" sudo -u "$TEST_USER" container image list &>/dev/null; do
    attempts=$((attempts + 1))
    if [[ "$attempts" -ge 30 ]]; then
      echo "Error: container apiserver did not become ready after 30 seconds" >&2
      exit 1
    fi
    sleep 1
  done
  echo "Container apiserver is ready."
}

setup_test_directories() {
  PEN_SOURCE="/Users/$TEST_USER/pen-source"
  cp -R "$PEN_HOME" "$PEN_SOURCE"
  chown -R "$TEST_USER:staff" "$PEN_SOURCE"

  TEST_PROJECT="/Users/$TEST_USER/test-project"
  sudo -u "$TEST_USER" mkdir -p "$TEST_PROJECT"
}

run_bats() {
  export TEST_USER
  export TEST_UID="$(id -u "$TEST_USER")"
  export PEN_SOURCE
  export TEST_PROJECT
  bats "${PEN_HOME}/test/e2e/"
}

# --- Main ---

require_root
delete_test_user
trap delete_test_user EXIT
create_test_user
copy_container_data
start_container_apiserver
setup_test_directories
run_bats
