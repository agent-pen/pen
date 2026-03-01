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
  local sanitized_user="${TEST_USER//./_}"
  rm -f "/etc/sudoers.d/pen-${sanitized_user}"

  if id "$TEST_USER" &>/dev/null; then
    sysadminctl -deleteUser "$TEST_USER" -secure 2>&1 || true
  fi
}

create_test_user() {
  sysadminctl -addUser "$TEST_USER" \
    -fullName "pen test user" \
    -password "$TEST_PASSWORD" \
    -home "/Users/$TEST_USER" 2>&1

  createhomedir -c -u "$TEST_USER" 2>&1
}

copy_container_kernel() {
  local kernels_subpath="Library/Application Support/com.apple.container/kernels"
  local sudo_user_home
  sudo_user_home="$(eval echo "~${SUDO_USER}")"
  local kernel_src="$sudo_user_home/$kernels_subpath"
  local kernel_dst="/Users/$TEST_USER/$kernels_subpath"

  if [[ -d "$kernel_src" ]]; then
    sudo -u "$TEST_USER" mkdir -p "$kernel_dst"
    cp "$kernel_src"/* "$kernel_dst"/
    chown -R "$TEST_USER:staff" "$kernel_dst"
  else
    echo "Warning: No container kernel found at $kernel_src"
    echo "The test run will trigger a several-hundred-MB kernel download, which may take a while."
  fi
}

clone_pen_for_test_user() {
  TEST_PROJECT="/Users/$TEST_USER/pen"
  git clone --local "$PEN_HOME" "$TEST_PROJECT"
  chown -R "$TEST_USER:staff" "$TEST_PROJECT"
}

run_bats() {
  export TEST_USER
  export TEST_UID="$(id -u "$TEST_USER")"
  export TEST_PROJECT
  bats "${PEN_HOME}/test/e2e/"
}

# --- Main ---

require_root
delete_test_user
trap delete_test_user EXIT
create_test_user
copy_container_kernel
clone_pen_for_test_user
run_bats
