load test_helper

PROJECT_DIR="$HOME/test-project-build"

setup_file() {
  setup_test_project "$PROJECT_DIR"
}

teardown_file() {
  cleanup_test_project "$PROJECT_DIR"
}

setup() {
  ensure_test_isolation "$PROJECT_DIR"
  cd "$PROJECT_DIR"
}

@test "pen build creates a sandbox that pen exec can use" {
  expect_failure pen exec true

  expect_success pen build
  expect_success pen exec true
}

@test "pen build uses custom Dockerfile when present in .pen/" {
  expect_failure pen exec true

  cp "$(default_dockerfile_path)" "$PROJECT_DIR/.pen/Dockerfile"
  echo "RUN touch /etc/pen-custom-build" >> "$PROJECT_DIR/.pen/Dockerfile"
  expect_success pen build
  expect_success pen exec test -f /etc/pen-custom-build
}
