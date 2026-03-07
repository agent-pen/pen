#!/usr/bin/env bash
# Create the e2e test user. Prints the new user's UID to stdout.
# Must be run as root.

set -o nounset -o errexit -o pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Error: must be run as root." >&2
  exit 1
fi

TEST_USER="pen-e2e-test-user"

password="$(openssl rand -hex 16)"

# FDE (FileVault) warning is expected — suppressing it requires admin credentials
# which we don't have non-interactively. The test user doesn't need FDE.
sysadminctl -addUser "$TEST_USER" \
  -fullName "pen test user" \
  -password "$password" \
  -home "/Users/$TEST_USER" >&2

# sysadminctl -createHomeDirectory is broken — use createhomedir instead.
createhomedir -c -u "$TEST_USER" >&2

id -u "$TEST_USER"
