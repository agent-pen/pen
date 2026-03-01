# 24. UID-based sudoers file naming

Date: 2026-03-01

## Status

Accepted

Supercedes [19. Per-user sudoers file](0019-per-user-sudoers-file.md)

## Context

ADR 0019 named sudoers files `/etc/sudoers.d/pen-$(whoami)` to allow multiple users to coexist. However, `install.sh` runs via `sudo`, where `$(whoami)` returns `root`. The script uses `$SUDO_USER` to identify the real user, but usernames can contain characters that are problematic in filenames and sudoers paths.

UIDs are guaranteed to be numeric and unique per user on macOS.

## Decision

Name sudoers files `/etc/sudoers.d/pen-<UID>` where UID is the numeric user ID of the installing user (resolved from `$SUDO_USER`). Both `install.sh` and `uninstall.sh` use this scheme. The dev sudoers file (`develop.sh`) follows the same pattern: `/etc/sudoers.d/pen-dev-<UID>`.

## Consequences

- Sudoers filenames are always safe — no special characters, no ambiguity.
- The `$(whoami)` pitfall under sudo is eliminated.
- Existing installs using the old naming scheme need a manual cleanup of the stale `/etc/sudoers.d/pen-<username>` file, or a fresh `uninstall.sh` + `install.sh` cycle.
