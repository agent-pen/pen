# 41. Consolidated privileged pf-anchor script for test infrastructure

Date: 2026-03-16

## Status

Accepted

## Context

Test cleanup previously called production `pfctl-wrapper.sh` (via sudo) to flush pf anchors — using production code for test orchestration. Two additional privileged test scripts existed: `clear-pf-anchors.sh` (flush all anchors by prefix) and `check-pf-anchor.sh` (check if a specific anchor has rules). This meant three privileged scripts touching pf, with the production one used in test infrastructure.

Additionally, `clear-pf-anchors.sh` used `pfctl -s anchors` which is not valid on macOS. The correct syntax for listing nested anchors under `com.apple/` is `pfctl -a 'com.apple' -s Anchors`.

## Decision

Consolidate into a single `pf-anchor.sh` in `test/suite/` with subcommands:

- `read <anchor>` — exit 0 if the anchor has rules loaded, exit 1 otherwise. Queries via `pfctl -a <anchor> -s rules`. Anchor argument is required.
- `flush` (no argument) — flush all pen anchors for the invoking user. Lists sub-anchors via `pfctl -a 'com.apple' -s Anchors`, filters for `pen-user-<uid>-project-` prefix.
- `flush <anchor>` — flush a specific anchor. Validates the anchor starts with `com.apple/pen-user-<uid>-project-`.

Self-contained (no user-writable dependencies), root-owned, scoped to the invoking user's UID via `SUDO_UID`. Registered in `grant-test-privileges.sh` for passwordless sudo.

Delete `clear-pf-anchors.sh` and `check-pf-anchor.sh`.

## Consequences

- Test infrastructure no longer depends on production `pfctl-wrapper.sh`.
- One privileged script instead of two (simpler sudoers configuration).
- Uses correct macOS pfctl syntax for querying nested anchors.
- The `validate_anchor` guard prevents the script from being pointed at arbitrary pf anchors, but this guard is not itself tested (testing test infrastructure was deemed out of scope).
