# 31. Root-own sudoers-allowed scripts in test user home

Date: 2026-03-09

## Status

Accepted

## Context

The e2e test user is granted passwordless sudo to `install.sh` and `uninstall.sh` in their home directory (`/Users/pen-test-user/pen-source/`). These scripts are copied from the developer's working tree by `copy-pen-source.sh`, which chowns the entire source tree to the test user so the test user can read and execute it.

This meant the test user could modify `install.sh` or `uninstall.sh` — scripts that sudoers allows them to run as root — and execute arbitrary code with root privileges. During automated test runs the window is brief and the user is ephemeral, but during interactive debugging sessions via `test-user-shell.sh` the window is indefinite.

ADR 0028 hardened the test infrastructure scripts (in `test/libs/privileged/`) with root ownership and guards. This decision addresses the other side: scripts in the test user's home that are granted sudo.

## Decision

`grant-test-privileges.sh` (renamed from `add-test-sudoers.sh`) now owns the full concern of securing scripts for privileged execution:

1. **Guard**: Verify `install.sh` and `uninstall.sh` exist at the expected paths before proceeding.
2. **Root-own**: `chown root:wheel` both scripts so the test user cannot modify them.
3. **Sudoers**: Create the scoped sudoers file granting the test user passwordless sudo to those scripts.

These three steps are in a single script rather than spread across `copy-pen-source.sh` and `add-test-sudoers.sh`, following the principle of high cohesion within modules: the concern of "granting privileged execution" includes both file ownership and sudoers configuration.

## Consequences

- The test user can execute `install.sh` and `uninstall.sh` as root but cannot modify them, closing the privilege escalation vector.
- The rename from `add-test-sudoers.sh` to `grant-test-privileges.sh` better communicates the script's full responsibility.
- `copy-pen-source.sh` remains focused on copying — it does not need to know which files will later be granted privileges.
- If new scripts are added to sudoers in future, the existence guard and root-ownership logic in `grant-test-privileges.sh` must be extended to cover them.
