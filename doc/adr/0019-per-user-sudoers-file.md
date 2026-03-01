# 19. Per-user sudoers file

Date: 2026-02-28

## Status

Superceded by [24. UID-based sudoers file naming](0024-uid-based-sudoers-file-naming.md)

Extends [15. Grant sudo to script for passwordless firewall management](0015-grant-sudo-to-script-for-passwordless-firewall-management.md)

## Context

ADR 0015 established that `install.sh` grants passwordless sudo to a dedicated pfctl wrapper script via a sudoers file. The current implementation writes a single file at `/etc/sudoers.d/pen`, containing a grant for `$(whoami)`.

If a second user runs `install.sh` — as required for end-to-end testing under a temporary user (ADR 0018) — the file is overwritten, revoking the first user's grant. Two users cannot have independent pen installations simultaneously.

## Decision

We will name the sudoers file `/etc/sudoers.d/pen-$(whoami)` so that each user's grant is stored in a separate file and coexists with other users' grants.

Both `install.sh` and `uninstall.sh` will be updated to use the per-user filename.

## Consequences

- Multiple users can install pen on the same machine without interfering with each other.
- Each user's `uninstall.sh` only removes their own sudoers entry.
- The install still requires a one-time password prompt for writing to `/etc/sudoers.d/`.
