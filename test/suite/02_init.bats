load test_helper

setup() {
  ensure_test_isolation
  ensure_pen_installed
}

sandbox_config_dir() {
  local project_name
  project_name="$(basename "$(project_dir)")"
  local matches=("$HOME"/.pen/sandboxes/*"$project_name"*)
  echo "${matches[0]}"
}

@test "pen init creates project runtime directory" {
  pen init
  assert_directory_exists "$(project_dir)/.pen"
}

@test "pen init creates sandbox config directory" {
  pen init
  assert_directory_exists "$(sandbox_config_dir)"
  assert_directory_not_empty "$(sandbox_config_dir)"
}

@test "pen init gitignores runtime artifacts in .pen" {
  pen init
  assert_file_contains "$(project_dir)/.pen/.gitignore" "proxy.pid"
  assert_file_contains "$(project_dir)/.pen/.gitignore" "proxy.log"
}

@test "pen init aborts early if sandbox config dir exists" {
  pen init

  rm -rf "$(project_dir)/.pen"
  rm -f "$(sandbox_config_dir)"/*

  expect_success pen init
  assert_output_contains "Already initialized"

  assert_directory_not_exists "$(project_dir)/.pen"
  assert_directory_empty "$(sandbox_config_dir)"
}
