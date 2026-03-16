load test_helper

setup() {
  ensure_test_isolation
  ensure_pen_project_built
}

teardown() {
  cleanup_test_resources
}

@test "container name matches test helper derivation" {
  pen exec true
  local expected
  expected="$(test_container_name "$(project_dir)")"
  run container list --format json
  assert_output_contains "$expected"
}

@test "network name matches test helper derivation" {
  pen exec true
  local expected
  expected="$(test_network_name "$(project_dir)")"
  run container network list --format json
  assert_output_contains "$expected"
}

@test "image reference starts with test helper sandbox name" {
  local expected
  expected="$(test_sandbox_name "$(project_dir)")"
  run container image list --format json
  assert_output_contains "$expected"
}

@test "sandbox config dir matches test helper derivation" {
  local expected
  expected="$(test_sandbox_config_dir "$(project_dir)")"
  assert_directory_exists "$expected"
}
