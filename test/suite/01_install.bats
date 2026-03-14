load test_helper

PROJECT_DIR="$HOME/test-project-install"

setup_file() {
  create_test_project "$PROJECT_DIR"
}

teardown_file() {
  cleanup_test_project "$PROJECT_DIR"
}

@test "pen command is available" {
  expect_success command -v pen
}

@test "~/.pen directory is created" {
  expect_success test -d "$HOME/.pen"
}

@test "only the pfctl wrapper is granted sudoers" {
  # sudo -l lists NOPASSWD entries with full paths — no root access needed.
  # Filter out install.sh and uninstall.sh (granted by test infrastructure, not pen).
  local pen_scripts
  pen_scripts="$(sudo -l 2>/dev/null \
    | grep 'NOPASSWD:' \
    | sed 's/.*NOPASSWD: //' \
    | grep -v '/install\.sh$' \
    | grep -v '/uninstall\.sh$')"

  # Exactly one entry: the pfctl wrapper
  local count
  count="$(echo "$pen_scripts" | wc -l | tr -d ' ')"
  [[ "$count" -eq 1 ]] || {
    echo "Expected 1 sudoers entry, got $count:" >&2
    echo "$pen_scripts" >&2
    return 1
  }

  local script="$pen_scripts"
  [[ "$script" == */penctl/commands/lib/pfctl-wrapper.sh ]] || {
    echo "Expected pfctl-wrapper.sh, got: $script" >&2
    return 1
  }

  # The script must be owned by root and not writable by the test user
  local owner
  owner="$(stat -f '%Su' "$script")"
  [[ "$owner" == "root" ]] || {
    echo "Expected owner root, got: $owner" >&2
    return 1
  }
  expect_failure test -w "$script"
}

@test "install.sh must be run with sudo" {
  run "$PEN_REPO/install.sh"
  [[ "$status" -ne 0 ]]
  assert_output_contains "must be run with sudo"
}
