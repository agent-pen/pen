load test_helper

setup() {
  ensure_test_isolation
  ensure_pen_installed
}

@test "happy path: build, exec, stop" {
  pen init
  expect_success pen build
  expect_success pen exec whoami
  assert_output_contains "root"
  expect_success pen status
  expect_success pen stop
  expect_failure pen status
}
