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
  run sudo "$PEN_REPO/install.sh"
  assert_success
  run command -v pen
  assert_success
}

@test "pen init" {
  run pen init
  assert_success
  [[ -d .pen ]]
}

@test "pen build with fixture Dockerfile" {
  cp "$PEN_REPO/test/suite/fixtures/Dockerfile.minimal" .pen/Dockerfile
  run pen build
  assert_success
}

@test "pen exec runs command in sandbox" {
  run pen exec whoami
  assert_success
  assert_output_contains "root"
}

@test "pen stop" {
  run pen status
  assert_success
  run pen stop
  assert_success
  run pen status
  assert_failure
}

@test "uninstall pen" {
  run sudo "$PEN_REPO/uninstall.sh"
  assert_success
  run command -v pen
  assert_failure
}
