# Shared helpers for pen e2e tests.
# Loaded explicitly by each .bats file.

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
