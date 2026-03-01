# bats suite-level helpers for pen e2e tests.
# Sourced automatically by bats via setup_suite convention.
#
# Expects these environment variables (set by test/run-e2e.sh):
#   TEST_USER    — the temporary macOS user name
#   TEST_UID     — the temporary macOS user's UID
#   TEST_PROJECT — path to the pen clone in the test user's home

setup_suite() {
  :
}

# Run an arbitrary command as the test user via launchctl asuser.
run_as_test_user() {
  sudo launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" "$@"
}

# Run a pen subcommand in the test project directory.
# Sets PATH explicitly so pen and its dependencies are found.
# install.sh expects to be run via sudo, where SUDO_USER identifies the
# target user. We're already root, so we simulate that contract.
run_as_sudo_user() {
  local user="$1"; shift
  sudo SUDO_USER="$user" "$@"
}

pen_run() {
  local test_user_home="/Users/$TEST_USER"
  run_as_test_user env \
    PATH="${test_user_home}/.local/bin:${PATH}" \
    pen "$@"
}
