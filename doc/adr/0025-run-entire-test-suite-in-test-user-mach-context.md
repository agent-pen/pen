# 25. Run entire test suite in test user Mach context

Date: 2026-03-08

## Status

Accepted

## Context

The E2E tests run under a temporary macOS user (ADR 0018). pen depends on the Apple Container apiserver, which is a per-user launch agent registered in the user's launchd domain. The apiserver requires the calling process to be in the correct Mach bootstrap context — the per-user `user/<uid>` service namespace managed by launchd.

Two approaches were considered:

1. **Per-command context switch.** The bats suite runs as the dev user. Each pen command is wrapped with `launchctl asuser <uid> sudo -u <test-user> pen ...`. This keeps test orchestration simple but creates process context mismatches: background processes spawned by pen (e.g. mitmdump) inherit the wrapper's context rather than running natively as the test user, causing failures like mitmdump being unable to bind to vmnet interfaces.

2. **Full suite context switch.** The entire bats process runs inside the test user's Mach context. All pen commands, background processes, and child processes run natively as the test user with no context mismatch.

## Decision

The entire bats test suite runs inside the test user's Mach context. A privileged orchestrator (`run-test-suite.sh`) hands off to the test user via `run_as_test_user`, which calls `launchctl asuser <uid> ... sudo -i -u <test-user> test/run.sh`. The bats process and all pen commands execute natively as the test user.

This drives a three-script split — `test/setup.sh`, `test/run.sh`, `test/teardown.sh` — because setup and teardown require root while the test run must execute as the test user. The split also enables an interactive debugging workflow: run setup, drop into a test user shell, investigate, then teardown.

## Consequences

- Background processes (mitmdump, container apiserver) run in the correct Mach context without wrappers.
- Test code is simpler — no per-command `launchctl asuser` wrappers or helper functions in bats.
- Setup and teardown are separate scripts that run as root, creating a clear privilege boundary.
- Developers can debug interactively: run setup, then `sudo test/libs/privileged/shell-test-user.sh pen-test-user` to get a test user shell.
