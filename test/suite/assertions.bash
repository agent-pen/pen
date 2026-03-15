# Custom test assertions.
# Sourced by test_helper.bash.

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

assert_file_exists() {
  if [[ ! -f "$1" ]]; then
    echo "assert_file_exists: file not found: $1" >&2
    return 1
  fi
}

assert_directory_not_exists() {
  if [[ -d "$1" ]]; then
    echo "assert_directory_not_exists: directory exists: $1" >&2
    return 1
  fi
}

assert_file_not_exists() {
  if [[ -f "$1" ]]; then
    echo "assert_file_not_exists: file exists: $1" >&2
    return 1
  fi
}

assert_directory_not_empty() {
  if [[ ! -d "$1" ]]; then
    echo "assert_directory_not_empty: directory not found: $1" >&2
    return 1
  fi
  local count
  count=$(ls "$1" | wc -l)
  if [[ "$count" -eq 0 ]]; then
    echo "assert_directory_not_empty: directory is empty: $1" >&2
    return 1
  fi
}

assert_directory_empty() {
  if [[ ! -d "$1" ]]; then
    echo "assert_directory_empty: directory not found: $1" >&2
    return 1
  fi
  local count
  count=$(ls "$1" | wc -l)
  if [[ "$count" -ne 0 ]]; then
    echo "assert_directory_empty: directory is not empty: $1" >&2
    return 1
  fi
}

assert_file_contains() {
  local path="$1" expected="$2"
  if [[ ! -f "$path" ]]; then
    echo "assert_file_contains: file not found: $path" >&2
    return 1
  fi
  grep -qF "$expected" "$path" || {
    echo "assert_file_contains: expected file to contain: $expected" >&2
    echo "file: $path" >&2
    return 1
  }
}

assert_output_contains() {
  if [[ -z "${output+x}" ]]; then
    echo "assert_output_contains: \$output is not set — did you forget 'run'?" >&2
    return 1
  fi
  [[ "$output" == *"$1"* ]] || {
    echo "assert_output_contains: expected output to contain: $1" >&2
    echo "actual output: $output" >&2
    return 1
  }
}

assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    echo "assert_failure: expected non-zero exit, got 0" >&2
    echo "output: $output" >&2
    return 1
  fi
}

assert_owned_by() {
  local expected_owner="$1" path="$2"
  local actual_owner
  actual_owner="$(stat -f '%Su' "$path")"
  [[ "$actual_owner" == "$expected_owner" ]] || {
    echo "assert_owned_by: expected owner $expected_owner, got $actual_owner: $path" >&2
    return 1
  }
}

assert_line_count() {
  local expected="$1" actual="$2" context="${3:-}"
  [[ "$actual" -eq "$expected" ]] || {
    echo "assert_line_count: expected $expected, got $actual${context:+ ($context)}" >&2
    return 1
  }
}

assert_glob_match() {
  local pattern="$1" value="$2"
  # shellcheck disable=SC2254
  case "$value" in
    $pattern) ;;
    *) echo "assert_glob_match: expected pattern $pattern, got: $value" >&2; return 1 ;;
  esac
}
