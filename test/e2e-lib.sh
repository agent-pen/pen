# Shared helpers for e2e test scripts. Sourced, not executed.

TEST_USER="pen-e2e-test-user"

delete_test_user() {
  if ! id "$TEST_USER" &>/dev/null; then
    return
  fi

  local uid
  uid="$(id -u "$TEST_USER")"

  rm -f "/etc/sudoers.d/pen-${uid}-e2e-test"
  rm -f "/etc/sudoers.d/pen-${uid}"

  # sysadminctl -deleteUser fails if the home directory is missing.
  # Ensure it exists and is owned by the user so sysadminctl deletes it.
  mkdir -p "/Users/$TEST_USER"
  chown "$TEST_USER" "/Users/$TEST_USER"

  sysadminctl -deleteUser "$TEST_USER" 2>&1 || true
}
