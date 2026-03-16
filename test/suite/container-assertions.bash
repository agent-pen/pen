# Assertions for Apple container CLI resources.
# Sourced by test_helper.bash.

assert_container_exists() {
  local expected="$1"
  local json
  json="$(container list --format json 2>/dev/null)"
  local actual
  actual="$(echo "$json" | jq -r "[.[] | select(.configuration.id == \"$expected\")][0].configuration.id")"
  [[ "$actual" == "$expected" ]] || {
    echo "assert_container_exists: container not found: $expected" >&2
    return 1
  }
}

assert_network_exists() {
  local expected="$1"
  local json
  json="$(container network list --format json 2>/dev/null)"
  local actual
  actual="$(echo "$json" | jq -r "[.[] | select(.id == \"$expected\")][0].id")"
  [[ "$actual" == "$expected" ]] || {
    echo "assert_network_exists: network not found: $expected" >&2
    return 1
  }
}

assert_image_exists() {
  local expected="$1"
  local json
  json="$(container image list --format json 2>/dev/null)"
  local actual
  actual="$(echo "$json" | jq -r "[.[] | select(.reference == \"$expected\")][0].reference")"
  [[ "$actual" == "$expected" ]] || {
    echo "assert_image_exists: image not found: $expected" >&2
    return 1
  }
}

assert_container_not_exists() {
  local name="$1"
  local json
  json="$(container list --format json 2>/dev/null)" || return 0
  local match
  match="$(echo "$json" | jq -r "[.[] | select(.configuration.id == \"$name\")][0].configuration.id")"
  [[ "$match" == "null" || -z "$match" ]] || {
    echo "assert_container_not_exists: container exists: $name" >&2
    return 1
  }
}

assert_network_not_exists() {
  local name="$1"
  local json
  json="$(container network list --format json 2>/dev/null)" || return 0
  local match
  match="$(echo "$json" | jq -r "[.[] | select(.id == \"$name\")][0].id")"
  [[ "$match" == "null" || -z "$match" ]] || {
    echo "assert_network_not_exists: network exists: $name" >&2
    return 1
  }
}

assert_image_not_exists() {
  local name="$1"
  local json
  json="$(container image list --format json 2>/dev/null)" || return 0
  local match
  match="$(echo "$json" | jq -r "[.[] | select(.reference == \"$name\")][0].reference")"
  [[ "$match" == "null" || -z "$match" ]] || {
    echo "assert_image_not_exists: image exists: $name" >&2
    return 1
  }
}

assert_pf_anchor_not_exists() {
  local anchor="$1"
  if sudo "$PEN_REPO/test/suite/check-pf-anchor.sh" "$anchor" 2>/dev/null; then
    echo "assert_pf_anchor_not_exists: anchor has rules: $anchor" >&2
    return 1
  fi
}

assert_pf_anchor_exists() {
  local anchor="$1"
  sudo "$PEN_REPO/test/suite/check-pf-anchor.sh" "$anchor" || {
    echo "assert_pf_anchor_exists: anchor has no rules: $anchor" >&2
    return 1
  }
}
