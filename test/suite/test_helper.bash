# Shared helpers for pen e2e tests.
# Loaded explicitly by each .bats file.

project_dir() {
  echo "${BATS_TEST_TMPDIR}/test-project"
}

# --- Name derivation helpers ---
# Duplicates production logic (common.sh) intentionally — tests should not
# depend on production code. setup_suite verifies these stay in sync.

test_sandbox_prefix() {
  echo "pen-user-$(id -u)-project-"
}

test_sandbox_name() {
  local dir="$1"
  local path_hash
  path_hash=$(printf '%s' "$dir" | shasum | cut -c1-6)
  echo "$(test_sandbox_prefix)$(basename "$dir")-${path_hash}"
}

test_container_name() { echo "$(test_sandbox_name "$1")-container"; }
test_network_name()   { echo "$(test_sandbox_name "$1")-network"; }
test_pf_anchor()      { echo "com.apple/$(test_sandbox_name "$1")"; }
test_sandbox_config_dir() { echo "$HOME/.pen/sandboxes/$(test_sandbox_name "$1")"; }

# Convenience wrapper defaulting to this test's project dir.
sandbox_config_dir() { test_sandbox_config_dir "$(project_dir)"; }

# --- Setup and teardown helpers ---

ensure_pen_installed() {
  command -v pen > /dev/null
}

ensure_pen_image_available() {
  local prebuilt_image_file=/tmp/pen-test-prebuilt-image
  if [[ ! -f "$prebuilt_image_file" ]]; then
    echo "ensure_pen_image_available: $prebuilt_image_file not found — was setup_suite run?" >&2
    return 1
  fi
  local prebuilt_image
  prebuilt_image="$(cat "$prebuilt_image_file")"
  local sandbox_name
  sandbox_name="$(test_sandbox_name "$(project_dir)")"
  container image tag "$prebuilt_image" "${sandbox_name}:latest"
}

ensure_pen_project_initialised() {
  ensure_pen_installed
  cd "$(project_dir)"
  pen init
  # Pre-tag so container build reuses cached layers instead of rebuilding.
  ensure_pen_image_available
}

ensure_pen_project_built() {
  ensure_pen_project_initialised
  pen build
}

# Tear down all sandbox resources for a given project directory.
# Uses low-level commands — no production code (pen stop).
# Pass --keep-image to skip image deletion (used by setup_suite to
# preserve the pre-built image for test reuse).
cleanup_sandbox() {
  local dir="$1"
  local keep_image=false
  [[ "${2:-}" == "--keep-image" ]] && keep_image=true

  local target
  target="$(test_container_name "$dir")"
  container delete --force "$target" 2>/dev/null || true

  local proxy_pid_file="${dir}/.pen/proxy.pid"
  if [[ -f "$proxy_pid_file" ]]; then
    kill "$(cat "$proxy_pid_file")" 2>/dev/null || true
  fi

  local anchor
  anchor="$(test_pf_anchor "$dir")"
  sudo "$PEN_REPO/test/suite/pf-anchor.sh" flush "$anchor" 2>/dev/null || true

  local network
  network="$(test_network_name "$dir")"
  container network delete "$network" 2>/dev/null || true

  if [[ "$keep_image" == false ]]; then
    container image delete --force "$(test_sandbox_name "$dir")" 2>/dev/null || true
  fi
  rm -rf "$(test_sandbox_config_dir "$dir")" 2>/dev/null || true
}

# Tear down resources for THIS test's project dir.
cleanup_test_resources() {
  cd "$HOME"
  cleanup_sandbox "$(project_dir)"
}

# Clean slate for a test method. Creates project dir, precautionary cleanup
# of stale resources (supports rerunning without prior teardown).
ensure_test_isolation() {
  cd "$HOME"
  mkdir -p "$(project_dir)"
  cd "$(project_dir)"
  cleanup_sandbox "$(project_dir)"
}

# --- Utility helpers ---

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

# List pen-granted NOPASSWD scripts (excludes test infrastructure entries).
pen_sudoers_scripts() {
  sudo -l 2>/dev/null \
    | grep 'NOPASSWD:' \
    | sed 's/.*NOPASSWD: //' \
    | grep -v '/install\.sh$' \
    | grep -v '/uninstall\.sh$' \
    | grep -v '/pf-anchor\.sh$'
}

SUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SUITE_DIR}/assertions.bash"
source "${SUITE_DIR}/container-assertions.bash"
