# 20. Install into per-user path

Date: 2026-02-28

## Status

Accepted

Supercedes [9. install-into-path](0009-install-into-path.md)

## Context

ADR 0009 established that `install.sh` symlinks pen into `/usr/local/bin/pen` using `sudo`. This is a system-wide location — only one user can own the symlink at a time. A second user running `install.sh` overwrites the first user's symlink.

This is a problem for end-to-end testing (ADR 0018), which runs pen under a dedicated test user (`pen-e2e-test-user`) on the same machine. It also requires `sudo` during install, which is unnecessary for a symlink into the user's own PATH.

## Decision

Install the pen symlink into `~/.local/bin/pen` instead of `/usr/local/bin/pen`. No `sudo` is required.

The install script will verify that `~/.local/bin` is on `PATH` and warn if it is not.

## Consequences

- Multiple users can install pen on the same machine without interfering with each other.
- Install no longer requires `sudo` for the symlink (still required for the sudoers entry and pfctl-wrapper ownership).
- Users must have `~/.local/bin` on their PATH. The install script will warn if this is not the case.
