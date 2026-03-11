load test_helper

@test "install and uninstall pen" {
  expect_failure command -v pen
  expect_success sudo "$PEN_REPO/install.sh"
  expect_success command -v pen
  expect_success sudo "$PEN_REPO/uninstall.sh"
  expect_failure command -v pen
}
