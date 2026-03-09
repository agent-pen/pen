# Shared helpers for pen e2e tests.
# Loaded explicitly by each .bats file.

expect_success() {
  run "$@"
  if [ "$status" -ne 0 ]; then
    echo "expect_success: expected exit 0, got $status" >&2
    echo "command: $*" >&2
    echo "output: $output" >&2
    return 1
  fi
}

expect_failure() {
  run "$@"
  if [ "$status" -eq 0 ]; then
    echo "expect_failure: expected non-zero exit, got 0" >&2
    echo "command: $*" >&2
    echo "output: $output" >&2
    return 1
  fi
}

assert_directory_exists() {
  if [[ ! -d "$1" ]]; then
    echo "assert_directory_exists: directory not found: $1" >&2
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
