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

  # Assert resources don't exist yet. Using assert_would_fail on the
  # "exists" assertions proves both absence AND that the assertions
  # actually fail when they should (can't be trivially true).
  assert_would_fail assert_container_exists "$container_name"
  assert_would_fail assert_network_exists "$network_name"
  assert_would_fail assert_image_exists "$image_ref"
  assert_would_fail assert_pf_anchor_exists "$anchor"
  assert_would_fail assert_directory_exists "$config_dir"

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

  # Persist image ref so tests can reuse it via tagging instead of rebuilding.
  echo "$image_ref" > /tmp/pen-test-prebuilt-image

  # Clean up everything except the image — tests will reuse it.
  cd "$HOME"
  container delete --force "$container_name" 2>/dev/null || true
  local proxy_pid_file="${verify_dir}/.pen/proxy.pid"
  if [[ -f "$proxy_pid_file" ]]; then
    kill "$(cat "$proxy_pid_file")" 2>/dev/null || true
  fi
  sudo "$PEN_REPO/test/suite/pf-anchor.sh" flush "$anchor" 2>/dev/null || true
  container network delete "$network_name" 2>/dev/null || true
  rm -rf "$config_dir" 2>/dev/null || true

  # Verify flush actually cleared the anchor.
  assert_pf_anchor_not_exists "$anchor"

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
  sudo "$PEN_REPO/test/suite/pf-anchor.sh" flush

  # Remove sandbox config directories
  local config_dir
  for config_dir in "$HOME"/.pen/sandboxes/${prefix}*; do
    [[ -d "$config_dir" ]] && rm -rf "$config_dir" || true
  done

  rm -f /tmp/pen-test-prebuilt-image
}
