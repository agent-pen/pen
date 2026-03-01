setup() {
  load setup_suite
}

@test "install.sh creates symlink and sudoers entry" {
  run_as_sudo_user "$TEST_USER" "$TEST_PROJECT/install.sh"

  local test_user_home="/Users/$TEST_USER"
  [ -L "${test_user_home}/.local/bin/pen" ]

  local sanitized_user="${TEST_USER//./_}"
  [ -f "/etc/sudoers.d/pen-${sanitized_user}" ]
}
