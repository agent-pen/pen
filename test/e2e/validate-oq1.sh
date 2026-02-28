#!/usr/bin/env basha
# Validate OQ-1: Does the Apple Container apiserver start under `launchctl asuser`?
#
# This script creates a temporary macOS user, attempts to run `container list`
# via `launchctl asuser`, and reports whether the approach works.
#
# Usage: sudo bash test/e2e/validate-oq1.sh

set -o nounset -o errexit -o pipefail

TEST_USER="pen-e2e-test-user"
TEST_PASSWORD="$(openssl rand -hex 16)"

# --- Cleanup ---

cleanup() {
  echo ""
  echo "--- Teardown ---"

  # Delete the test user and home directory
  if id "$TEST_USER" &>/dev/null; then
    echo "Deleting test user $TEST_USER..."
    sysadminctl -deleteUser "$TEST_USER" -secure 2>&1 || true
    echo "Test user deleted."
  else
    echo "Test user does not exist, nothing to clean up."
  fi
}

trap cleanup EXIT

# --- Defensive cleanup of prior run ---

if id "$TEST_USER" &>/dev/null; then
  echo "Test user $TEST_USER already exists from a previous run. Cleaning up first..."
  sysadminctl -deleteUser "$TEST_USER" -secure 2>&1 || true
  echo "Previous test user deleted."
  echo ""
fi

# --- Must run as root ---

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: This script must be run as root (use sudo)."
  exit 1
fi

# --- Create test user ---

echo "--- Setup ---"
echo "Creating test user $TEST_USER..."
sysadminctl -addUser "$TEST_USER" \
  -fullName "pen test user" \
  -password "$TEST_PASSWORD" \
  -home "/Users/$TEST_USER" \
  -createHomeDirectory 2>&1

echo "Test user created."

# Ensure home directory exists (sysadminctl sometimes doesn't create it)
if [[ ! -d "/Users/$TEST_USER" ]]; then
  echo "Home directory not created by sysadminctl, creating manually..."
  createhomedir -c -u "$TEST_USER" 2>&1
fi
echo "Home directory: $(ls -ld "/Users/$TEST_USER")"

# --- Validate ---

echo ""
echo "--- Validate: launchctl asuser + container list ---"

TEST_UID="$(id -u "$TEST_USER")"
echo "Test user UID: $TEST_UID"
# Copy kernel from invoking user to avoid ~450MB download; fall back to download
SUDO_USER_HOME="$(eval echo "~${SUDO_USER}")"
KERNEL_SRC="$SUDO_USER_HOME/Library/Application Support/com.apple.container/kernels"
KERNEL_DST="/Users/$TEST_USER/Library/Application Support/com.apple.container/kernels"

if [[ -d "$KERNEL_SRC" ]]; then
  echo "Copying kernel from $SUDO_USER to test user..."
  sudo -u "$TEST_USER" mkdir -p "$KERNEL_DST"
  cp "$KERNEL_SRC"/* "$KERNEL_DST"/
  chown -R "$TEST_USER:staff" "$KERNEL_DST"
  echo "Kernel copied: $(ls "$KERNEL_DST")"
  KERNEL_FLAG=""
else
  echo "No kernel found at $KERNEL_SRC, will download..."
  KERNEL_FLAG="--enable-kernel-install"
fi

echo "Starting container system service for test user..."
launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" container system start $KERNEL_FLAG 2>&1 || true
echo ""

echo "Running: launchctl asuser $TEST_UID sudo -u $TEST_USER container list"
echo ""

if output="$(launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" container list 2>&1)"; then
  echo "PASS: container list succeeded under launchctl asuser"
  echo "Output:"
  echo "$output"
else
  exit_code=$?
  echo "FAIL: container list failed (exit code $exit_code)"
  echo "Output:"
  echo "$output"
fi

# --- Validate: --enable-kernel-install is a no-op when kernel exists ---

echo ""
echo "--- Validate: --enable-kernel-install idempotency ---"
echo "Kernel already present at: $(ls "$KERNEL_DST" 2>/dev/null || echo '(not found)')"
echo "Running: container system start --enable-kernel-install (should be a no-op)..."
echo ""

if output="$(launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" container system start --enable-kernel-install 2>&1)"; then
  echo "PASS: --enable-kernel-install returned success"
else
  echo "WARN: --enable-kernel-install returned exit code $?"
fi
echo "Output:"
echo "$output"
