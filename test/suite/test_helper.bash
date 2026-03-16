# Shared helpers for pen e2e tests.
# Loaded explicitly by each .bats file.

project_dir() {
  echo "${BATS_TEST_TMPDIR}/test-project"
}

# --- Name derivation helpers ---
# Duplicates production logic (common.sh) intentionally — tests should not
# depend on production code. Naming tests verify these stay in sync.

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

ensure_pen_project_initialised() {
  ensure_pen_installed
  cd "$(project_dir)"
  pen init
}

ensure_pen_project_built() {
  ensure_pen_project_initialised
  pen build
}

# Tear down resources for THIS test's project dir only.
# Uses low-level commands — no production code (pen stop).
cleanup_test_resources() {
  local dir
  dir="$(project_dir)"
  local target
  target="$(test_container_name "$dir")"
  local network
  network="$(test_network_name "$dir")"
  local anchor
  anchor="$(test_pf_anchor "$dir")"
  local proxy_pid_file="${dir}/.pen/proxy.pid"

  container delete --force "$target" 2>/dev/null || true

  if [[ -f "$proxy_pid_file" ]]; then
    kill "$(cat "$proxy_pid_file")" 2>/dev/null || true
  fi

  sudo "$HOME/pen-source/penctl/commands/lib/pfctl-wrapper.sh" flush "$anchor" 2>/dev/null || true
  container network delete "$network" 2>/dev/null || true
  container image delete --force "$(test_sandbox_name "$dir")" 2>/dev/null || true
  rm -rf "$(test_sandbox_config_dir "$dir")" 2>/dev/null || true
}

# Clean slate for a test method. Creates project dir, precautionary cleanup
# of stale resources (supports rerunning without prior teardown).
ensure_test_isolation() {
  mkdir -p "$(project_dir)"
  cd "$(project_dir)"

  # Precautionary cleanup of stale resources from a previous run
  # (e.g. interactive debugging where teardown didn't complete).
  # Critical: flush pf anchor to prevent stale rules from interfering.
  local dir
  dir="$(project_dir)"
  local anchor
  anchor="$(test_pf_anchor "$dir")"
  container delete --force "$(test_container_name "$dir")" 2>/dev/null || true
  sudo "$HOME/pen-source/penctl/commands/lib/pfctl-wrapper.sh" flush "$anchor" 2>/dev/null || true
  container network delete "$(test_network_name "$dir")" 2>/dev/null || true
  container image delete --force "$(test_sandbox_name "$dir")" 2>/dev/null || true
  rm -rf "$(test_sandbox_config_dir "$dir")" 2>/dev/null || true
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
    | grep -v '/clear-pf-anchors\.sh$'
}

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/assertions.bash"
