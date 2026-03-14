load test_helper

PROJECT_DIR="$HOME/test-project-init"

setup_file() {
  create_test_project "$PROJECT_DIR"

  [[ ! -e "$(sandbox_config_dir)" ]] || {
    echo "setup_file: sandbox config dir already exists before init: $(sandbox_config_dir)" >&2
    return 1
  }

  cd "$PROJECT_DIR"
  pen init
}

teardown_file() {
  cleanup_test_project "$PROJECT_DIR"
}

sandbox_config_dir() {
  local project_name
  project_name="$(basename "$PROJECT_DIR")"
  local matches=("$HOME"/.pen/sandboxes/*"$project_name"*)
  echo "${matches[0]}"
}

@test "pen init creates project runtime directory" {
  assert_directory_exists "$PROJECT_DIR/.pen"
}

@test "pen init creates sandbox config with allowlists" {
  assert_directory_exists "$(sandbox_config_dir)"
  assert_directory_not_empty "$(sandbox_config_dir)"
}

@test "pen init gitignores runtime artifacts in .pen" {
  assert_file_contains "$PROJECT_DIR/.pen/.gitignore" "proxy.pid"
  assert_file_contains "$PROJECT_DIR/.pen/.gitignore" "proxy.log"
}

@test "pen init aborts early if sandbox config dir exists" {
  cd "$PROJECT_DIR"
  rm -rf "$PROJECT_DIR/.pen"
  rm -f "$(sandbox_config_dir)"/*

  expect_success pen init
  assert_output_contains "Already initialized"

  assert_directory_not_exists "$PROJECT_DIR/.pen"
  assert_directory_empty "$(sandbox_config_dir)"
}
