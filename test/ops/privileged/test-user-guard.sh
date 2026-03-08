#!/usr/bin/env bash
# Shared guards for e2e privileged leaf scripts: identity verification and
# controlled hand-off from root to the test user.
# This file is root:wheel owned and must not source any user-writable files.
#
# Provides:
#   verify_target_user <username>          — name + invoking-user check
#   verify_target_user_and_uid <username>  — additionally checks UID differs
#   verify_target_path <path>              — path is under test user home
#   run_as_test_user <username> [command]  — hand-off via launchctl + sudo -i

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Error: must be run as root." >&2
    exit 1
  fi
}

_INVOKING_USER="${SUDO_USER:?must be run via sudo}"
readonly _INVOKING_USER

# Compose expected values from parts so a bulk find-and-replace of the full
# username across the codebase cannot silently change these safety checks.
_EXPECTED_USER=""
printf -v _EXPECTED_USER '%s-%s' 'pen' 'test-user'
readonly _EXPECTED_USER

_EXPECTED_HOME="/Users/${_EXPECTED_USER}"
readonly _EXPECTED_HOME

verify_target_user() {
  local target="$1"

  if [[ "$target" != "$_EXPECTED_USER" ]]; then
    echo "FATAL: unexpected target user '$target' (expected '$_EXPECTED_USER')" >&2
    exit 1
  fi
  if [[ "$target" == "$_INVOKING_USER" ]]; then
    echo "FATAL: refusing to operate on invoking user '$_INVOKING_USER'" >&2
    exit 1
  fi
}

verify_target_user_and_uid() {
  local target="$1"

  verify_target_user "$target"

  if id "$target" &>/dev/null && id "$_INVOKING_USER" &>/dev/null; then
    if [[ "$(id -u "$target")" == "$(id -u "$_INVOKING_USER")" ]]; then
      echo "FATAL: target UID matches invoking user UID" >&2
      exit 1
    fi
  fi
}

run_as_test_user() {
  local target="$1"
  shift
  verify_target_user_and_uid "$target"
  local target_uid
  target_uid="$(id -u "$target")"
  launchctl asuser "$target_uid" env -i TERM="$TERM" LANG="$LANG" sudo -i -u "$target" "$@"
}

verify_target_path() {
  local path="$1"

  if [[ "$path" != "$_EXPECTED_HOME"* ]]; then
    echo "FATAL: target path '$path' is not under '$_EXPECTED_HOME'" >&2
    exit 1
  fi
  if [[ "$path" == *"$_INVOKING_USER"* ]]; then
    echo "FATAL: target path contains invoking user name '$_INVOKING_USER'" >&2
    exit 1
  fi
}
