source "$(dirname "${BASH_SOURCE[0]}")/test_helper.bash"

setup_suite() {
  sudo "$PEN_REPO/install.sh"
  verify_naming_contract
}

# Verify test helper name derivation matches production naming.
# Creates a temporary sandbox, checks all resource names, then tears down.
# Fails fast — if naming is out of sync, no tests will run.
verify_naming_contract() {
  local verify_dir
  verify_dir="$(mktemp -d)/test-project"
  mkdir -p "$verify_dir"

  local sandbox_name
  sandbox_name="$(test_sandbox_name "$verify_dir")"
  local container_name
  container_name="$(test_container_name "$verify_dir")"
  local network_name
  network_name="$(test_network_name "$verify_dir")"
  local image_ref="${sandbox_name}:latest"
  local anchor
  anchor="$(test_pf_anchor "$verify_dir")"
  local config_dir
  config_dir="$(test_sandbox_config_dir "$verify_dir")"

  # Ensure the container system is running so that list commands work.
  # Without this, "not exists" assertions pass trivially because the
  # commands fail (|| return 0) rather than returning empty results.
  if ! container system status &>/dev/null; then
    container system start --enable-kernel-install
  fi

  # Assert none of these resources exist yet — proves the names are
  # specific to this project dir, not coincidentally matching something
  # already present.
  assert_container_not_exists "$container_name"
  assert_network_not_exists "$network_name"
  assert_image_not_exists "$image_ref"
  assert_pf_anchor_not_exists "$anchor"
  assert_directory_not_exists "$config_dir"

  # Create the full sandbox lifecycle.
  cd "$verify_dir"
  pen init
  pen build
  pen exec true

  # Assert all resources now exist with the expected names.
  assert_container_exists "$container_name"
  assert_network_exists "$network_name"
  assert_image_exists "$image_ref"
  assert_pf_anchor_exists "$anchor"
  assert_directory_exists "$config_dir"

  # Verify "not exists" assertions detect actually-existing resources.
  # Without this, the pre-creation checks above can't be mutation-tested
  # (mktemp guarantees unique names, so they'd pass even if broken).
  assert_would_fail assert_container_not_exists "$container_name"
  assert_would_fail assert_network_not_exists "$network_name"
  assert_would_fail assert_image_not_exists "$image_ref"
  assert_would_fail assert_pf_anchor_not_exists "$anchor"
  assert_would_fail assert_directory_not_exists "$config_dir"

  cd "$HOME"
  cleanup_sandbox "$verify_dir"
  rm -rf "$verify_dir"
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
  sudo "$PEN_REPO/test/suite/clear-pf-anchors.sh"

  # Remove sandbox config directories
  local config_dir
  for config_dir in "$HOME"/.pen/sandboxes/${prefix}*; do
    [[ -d "$config_dir" ]] && rm -rf "$config_dir" || true
  done
}
