load test_helper

setup() {
  cd "$TEST_PROJECT"
}

teardown_file() {
  # Kill the proxy if still running so its inherited bats FDs are released
  # and bats can exit. Other resources (container, network, pf) are cleaned
  # up during test user deletion in teardown.sh.
  local proxy_pid_file="${TEST_PROJECT}/.pen/proxy.pid"
  if [[ -f "$proxy_pid_file" ]]; then
    kill "$(cat "$proxy_pid_file")" 2>/dev/null || true
    rm -f "$proxy_pid_file"
  fi
}

@test "install pen" {
  expect_success sudo "$PEN_REPO/install.sh"
  expect_success command -v pen
}

@test "pen init" {
  expect_success pen init
  assert_directory_exists .pen
}

@test "pen build" {
  expect_success pen build
}

@test "pen exec runs command in sandbox" {
  expect_success pen exec whoami
  assert_output_contains "root"
}

@test "pen stop" {
  expect_success pen status
  expect_success pen stop
  expect_failure pen status
}

@test "uninstall pen" {
  expect_success sudo "$PEN_REPO/uninstall.sh"
  expect_failure command -v pen
}
