load test_helper

PROJECT_DIR="$HOME/test-project-happy-path"

setup_file() {
  setup_test_project "$PROJECT_DIR"
}

teardown_file() {
  cleanup_test_project "$PROJECT_DIR"
}

@test "happy path: build, exec, stop" {
  cd "$PROJECT_DIR"
  expect_success pen build
  expect_success pen exec whoami
  assert_output_contains "root"
  expect_success pen status
  expect_success pen stop
  expect_failure pen status
}
