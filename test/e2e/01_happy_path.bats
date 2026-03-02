load test_helper

@test "install pen" {
  run as_sudo_user "$TEST_USER" "$PEN_SOURCE/install.sh"
  assert_success
}

@test "pen init" {
  run in_test_project pen init
  assert_success
}

@test "pen build with fixture Dockerfile" {
  run in_test_project cp "$PEN_SOURCE/test/e2e/fixtures/Dockerfile.minimal" .pen/Dockerfile
  assert_success

  run in_test_project pen build
  assert_success
}

@test "pen exec runs command in sandbox" {
  run in_test_project pen exec whoami
  assert_success
  assert_output_contains "root"
}

@test "pen stop" {
  run in_test_project pen stop
  assert_success
}

@test "uninstall pen" {
  run as_sudo_user "$TEST_USER" "$PEN_SOURCE/uninstall.sh"
  assert_success
}
