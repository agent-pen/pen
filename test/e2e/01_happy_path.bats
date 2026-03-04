load test_helper

setup() {
  cd "$TEST_PROJECT"
}

@test "install pen" {
  run sudo "$PEN_REPO/install.sh"
  assert_success
}

@test "pen init" {
  run pen init
  assert_success
}

@test "pen build with fixture Dockerfile" {
  cp "$PEN_REPO/test/e2e/fixtures/Dockerfile.minimal" .pen/Dockerfile
  run pen build
  assert_success
}

@test "pen exec runs command in sandbox" {
  run pen exec whoami
  assert_success
  assert_output_contains "root"
}

@test "pen stop" {
  run pen stop
  assert_success
}

@test "uninstall pen" {
  run sudo "$PEN_REPO/uninstall.sh"
  assert_success
}
