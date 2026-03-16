source "$(dirname "${BASH_SOURCE[0]}")/test_helper.bash"

setup_suite() {
  sudo "$PEN_REPO/install.sh"
}

# Safety-net sweep: clean up any resources leaked by tests that crashed
# or failed before their teardown() ran. Uses prefix-based matching.
teardown_suite() {
  local prefix
  prefix="$(test_sandbox_prefix)"

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
    [[ -d "$config_dir" ]] && rm -rf "$config_dir" || true
  done
}
