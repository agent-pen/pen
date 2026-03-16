bats_require_minimum_version 1.5.0

load test_helper

setup() {
  ensure_test_isolation
  ensure_pen_project_built
}

@test "pen exec runs command inside the container" {
  expect_success pen exec uname
  assert_output_contains "Linux"
}

@test "pen exec runs command in project-specific container" {
  echo "pen-test-content" > "$(project_dir)/marker"
  expect_success pen exec cat "$(project_dir)/marker"
  assert_output_contains "pen-test-content"
}

@test "pen exec passes stderr through" {
  run --separate-stderr pen exec sh -c "echo error >&2"
  assert_stderr_contains "error"
}

@test "pen exec propagates the container command's exit code" {
  run pen exec sh -c "exit 42"
  assert_exit_code 42
}

@test "pen exec reuses running sandbox on subsequent calls" {
  pen exec touch /tmp/pen-test-marker
  expect_success pen exec test -f /tmp/pen-test-marker
}
