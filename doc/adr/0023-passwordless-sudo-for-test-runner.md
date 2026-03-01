# 23. Passwordless sudo for test runner

Date: 2026-03-01

## Status

Accepted

Extends [15. Grant sudo to script for passwordless firewall management](0015-grant-sudo-to-script-for-passwordless-firewall-management.md)

## Context

The E2E test orchestrator (`test/run-e2e.sh`) must run as root to create and delete macOS users, copy files between user home directories, and invoke bats as the test user. Without passwordless sudo, every test run (including the git pre-commit hook) would prompt for a password.

ADR 0015 established the pattern of granting passwordless sudo to a specific root-owned script with restricted write access.

## Decision

`develop.sh` (one-time dev setup) creates a per-user sudoers entry at `/etc/sudoers.d/pen-dev-<UID>` granting passwordless sudo for `test/run-e2e.sh`. The script is owned by root:wheel with mode 755 to prevent modification by non-root users.

This follows the same pattern as the pfctl wrapper (ADR 0015): grant sudo to a specific script, restrict write access to root.

## Consequences

- Developers run tests without password prompts, including via the pre-commit hook.
- The sudoers entry is scoped to a single script, limiting the privilege grant.
- `develop.sh --undo` removes the sudoers entry and restores script ownership.
