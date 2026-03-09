load test_helper

PROJECT_DIR="$HOME/test-project-init"

setup_file() {
  install_pen
  create_test_project "$PROJECT_DIR"
}

teardown_file() {
  cleanup_test_project "$PROJECT_DIR"
}

@test "pen init creates .pen directory" {
  cd "$PROJECT_DIR"
  expect_success pen init
  assert_directory_exists .pen
}
