# 34. Kill proxy in bats teardown to prevent test runner hang

Date: 2026-03-09

## Status

Superceded by [37. Per-file test isolation with independent project directories](0037-per-file-test-isolation-with-independent-project-directories.md)

## Context

`pen start` launches the egress proxy (mitmdump wrapped in `script -qF`) as a background process. This process inherits file descriptors from its parent shell — including bats' FD 3, which bats uses for terminal output. Bats waits for all holders of its FDs to exit before it finishes.

When the `pen stop` test passes, `pen_teardown` kills the proxy and releases the FDs. But when `pen stop` is skipped or fails (e.g. during test development), the proxy keeps FD 3 open and bats hangs indefinitely after the last test completes.

The test infrastructure must be resilient to individual test failures without cascading into a hang. The cleanup cannot rely on pen's own code (`pen stop`) working correctly — that would create a circular dependency when testing pen itself.

## Decision

Add a `teardown_file` function to the bats test file that kills the proxy directly via its PID file (`$TEST_PROJECT/.pen/proxy.pid`). This runs once after all tests in the file complete, regardless of pass/fail status.

Only the proxy is killed — the container, network, and pf rules are left for the existing test user deletion in `teardown.sh`, which handles them as part of full account cleanup.

## Consequences

- Bats exits promptly even when `pen stop` is skipped or broken.
- The proxy PID file path (`$TEST_PROJECT/.pen/proxy.pid`) is duplicated between test and prod code. If the PID file location changes in `common.sh`, the test teardown must be updated to match.
- Other pen resources (container, network, pf anchors) are not cleaned up at the bats level. This is intentional — they don't hold bats FDs and are handled by test user deletion.
