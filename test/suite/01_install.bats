load test_helper

@test "pen command is available" {
  expect_success command -v pen
}

@test "~/.pen directory is created" {
  assert_directory_exists "$HOME/.pen"
}

@test "only the pfctl wrapper is granted sudoers" {
  local pen_scripts
  pen_scripts="$(pen_sudoers_scripts)"

  local count
  count="$(echo "$pen_scripts" | wc -l | tr -d ' ')"
  assert_line_count 1 "$count" "sudoers entries"
  assert_glob_match "*/penctl/commands/lib/pfctl-wrapper.sh" "$pen_scripts"
  assert_owned_by root "$pen_scripts"
  expect_failure test -w "$pen_scripts"
}

@test "install.sh must be run with sudo" {
  run "$PEN_REPO/install.sh"
  assert_failure
  assert_output_contains "must be run with sudo"
}
