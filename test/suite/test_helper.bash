# Shared helpers for pen e2e tests.
# Loaded explicitly by each .bats file.

project_dir() {
  echo "$HOME/test-project"
}

ensure_pen_installed() {
  command -v pen > /dev/null
}

ensure_pen_project_initialised() {
  cd "$(project_dir)"
  pen init
}

# Resolve PEN_HOME from the installed pen symlink.
pen_home() {
  local pen_path
  pen_path="$(readlink "$(command -v pen)")"
  dirname "$pen_path"
}

# Path to pen's default Dockerfile.
default_dockerfile_path() {
  echo "$(pen_home)/penctl/image/Dockerfile"
}

# Reset all pen state so each test starts from a clean slate.
# Uses a prefix-based approach so tests don't couple to pen's name derivation.
ensure_test_isolation() {
  local prefix="pen-user-$(id -u)-project-"

  # Stop and delete containers
  container list --format json 2>/dev/null \
    | jq -r '.[].configuration.id // empty' \
    | grep "^${prefix}" \
    | while IFS= read -r name; do
        container delete --force "$name" 2>/dev/null || true
      done || true

  # Delete networks
  container network list --format json 2>/dev/null \
    | jq -r '.[].id // empty' \
    | grep "^${prefix}" \
    | while IFS= read -r name; do
        container network delete "$name" 2>/dev/null || true
      done || true

  # Delete images
  container image list --format json 2>/dev/null \
    | jq -r '.[].reference // empty' \
    | grep "^${prefix}" \
    | while IFS= read -r ref; do
        container image delete --force "$ref" 2>/dev/null || true
      done || true

  # Kill mitmdump processes and wait for them to exit
  pkill -f mitmdump 2>/dev/null || true
  while pgrep -f mitmdump > /dev/null 2>&1; do
    sleep 0.1
  done

  # Clear pf anchors
  sudo "$HOME/pen-source/test/suite/clear-pf-anchors.sh"

  # Remove sandbox config directories
  local config_dir
  for config_dir in "$HOME"/.pen/sandboxes/${prefix}*; do
    [[ -d "$config_dir" ]] && rm -rf "$config_dir"
  done

  # Recreate project directory
  rm -rf "$(project_dir)"
  mkdir -p "$(project_dir)"
  cd "$(project_dir)"
}

# List pen-granted NOPASSWD scripts (excludes test infrastructure entries).
pen_sudoers_scripts() {
  sudo -l 2>/dev/null \
    | grep 'NOPASSWD:' \
    | sed 's/.*NOPASSWD: //' \
    | grep -v '/install\.sh$' \
    | grep -v '/uninstall\.sh$' \
    | grep -v '/clear-pf-anchors\.sh$'
}

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
