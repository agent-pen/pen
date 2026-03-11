load test_helper

@test "pen uninstall removes pen command" {
  expect_success command -v pen
  expect_success sudo "$PEN_REPO/uninstall.sh"
  expect_failure command -v pen
}
