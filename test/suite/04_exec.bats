bats_require_minimum_version 1.5.0

load test_helper

setup() {
  ensure_test_isolation
  ensure_pen_project_built
}

teardown() {
  cleanup_test_resources
}

@test "pen exec runs command inside the container" {
  expect_success pen exec uname
  assert_output_contains "Linux"
}

@test "pen exec mounts the project directory at the same path as on the host" {
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

@test "pen exec recovers after all sandbox processes die" {
  pen exec true
  container delete --force "$(test_container_name "$(project_dir)")"
  kill "$(cat "$(project_dir)/.pen/proxy.pid")"
  expect_success pen exec whoami
  assert_output_contains "root"
}

@test "pen exec fails if image has not been built" {
  container image delete --force "$(test_sandbox_name "$(project_dir)")"
  run --separate-stderr pen exec whoami
  assert_failure
  assert_stderr_contains "pen build"
}
