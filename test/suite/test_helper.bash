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

ensure_pen_project_built() {
  ensure_pen_project_initialised
  pen build
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

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/assertions.bash"
