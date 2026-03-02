# Shared helpers for pen e2e tests.
# Loaded explicitly by each .bats file and by setup_suite.bash.
#
# Expects these environment variables (set by test/run-e2e.sh):
#   TEST_USER    — the temporary macOS user name
#   TEST_UID     — the temporary macOS user's UID
#   PEN_SOURCE   — path to the pen source clone in the test user's home
#   TEST_PROJECT — path to an empty project directory in the test user's home

# Run an arbitrary command as the test user via launchctl asuser.
as_test_user() {
  sudo launchctl asuser "$TEST_UID" sudo -i -u "$TEST_USER" "$@"
}

# Some commands expect to be run via sudo, where SUDO_USER identifies the
# target user. We're already root, so we simulate that contract.
as_sudo_user() {
  local user="$1"; shift
  sudo SUDO_USER="$user" "$@"
}

# Run an arbitrary command as the test user, cd'd into the test project,
# with ~/.local/bin on PATH so pen and its dependencies are found.
in_test_project() {
  local test_user_home="/Users/$TEST_USER"
  as_test_user bash -c \
    "cd '${TEST_PROJECT}' && export HOME='${test_user_home}' && PATH='${test_user_home}/.local/bin:${PATH}' \"\$@\"" \
    -- "$@"
}

assert_success() {
  if [[ -z "${status+x}" ]]; then
    echo "assert_success: \$status is not set — did you forget 'run'?" >&2
    return 1
  fi
  if [ "$status" -ne 0 ]; then
    echo "assert_success: expected exit 0, got $status" >&2
    echo "output: $output" >&2
    return 1
  fi
}

assert_output_contains() {
  if [[ -z "${output+x}" ]]; then
    echo "assert_output_contains: \$output is not set — did you forget 'run'?" >&2
    return 1
  fi
  [[ "$output" == *"$1"* ]]
}
