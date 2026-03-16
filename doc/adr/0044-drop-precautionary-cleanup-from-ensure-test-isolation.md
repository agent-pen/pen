# 44. Drop precautionary cleanup from ensure-test-isolation

Date: 2026-03-16

## Status

Accepted

## Context

`ensure_test_isolation` called `cleanup_sandbox` at the start of every test method as a precaution against stale resources left by a previous run that failed before its teardown completed. The concern was an interactive debugging scenario: a developer runs a test, it crashes mid-way, then they re-run it and hit leftover containers, networks, or pf anchors from the first run.

However, `project_dir()` derives from `BATS_TEST_TMPDIR`, and Bats creates `BATS_TEST_TMPDIR` under a fresh `mktemp -d` directory (`bats-run-XXXXXX`) on every invocation. This means every test run gets a unique project directory path, which produces unique sandbox resource names (container, network, image, pf anchor — all derived from a hash of the project directory path). Stale resources from a prior run use different names and cannot collide.

The precautionary cleanup was therefore always a no-op — cleaning up resources that could not exist. Each call to `cleanup_sandbox` issued multiple `container` CLI commands (delete, network delete, image delete) plus a `sudo pfctl` flush, adding unnecessary overhead per test method under parallel execution.

## Decision

Remove the `cleanup_sandbox` call from `ensure_test_isolation`. The function now only creates the project directory and cd's into it.

Per-test teardown (`cleanup_test_resources`) still runs `cleanup_sandbox` to clean up resources created by the test itself. The `teardown_suite` safety-net sweep still catches any resources leaked by tests that crash before teardown completes.

## Consequences

- Removes unnecessary container CLI and pfctl calls from every test method's setup, reducing per-test overhead.
- If Bats ever changes `BATS_TEST_TMPDIR` to be deterministic rather than random, stale resources could collide. This is unlikely — Bats explicitly warns against reusing run directories — and would be caught by test failures.
- The safety-net sweep in `teardown_suite` remains the backstop for leaked resources across runs.
