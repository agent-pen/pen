load test_helper

setup() {
  ensure_test_isolation
  ensure_pen_project_initialised
}

@test "pen build creates a sandbox that pen exec can use" {
  expect_failure pen exec true

  expect_success pen build
  expect_success pen exec true
}

@test "pen build uses custom Dockerfile when present in .pen/" {
  expect_failure pen exec true

  cp "$(default_dockerfile_path)" "$(project_dir)/.pen/Dockerfile"
  echo "RUN touch /etc/pen-custom-build" >> "$(project_dir)/.pen/Dockerfile"
  expect_success pen build
  expect_success pen exec test -f /etc/pen-custom-build
}
