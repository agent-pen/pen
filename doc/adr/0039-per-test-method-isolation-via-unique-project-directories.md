# 39. Per-test-method isolation via unique project directories

Date: 2026-03-16

## Status

Accepted

Supercedes [38. Per-test isolation via setup](0038-per-test-isolation-via-setup.md)

## Context

ADR 0038 gave each test method a clean slate by nuking all pen resources matching the `pen-user-<uid>-project-` prefix before each test. This worked for serial execution but is incompatible with parallel execution (`bats --jobs`): one test's setup would destroy another test's running sandbox.

Sandbox identity is derived from the project path hash (`common.sh`). A different project directory produces a different `path_hash`, which produces different container, network, image, pf anchor, and config dir names. If each test method gets its own project directory, all resources are automatically namespaced.

## Decision

`project_dir()` returns `${BATS_TEST_TMPDIR}/test-project`. `BATS_TEST_TMPDIR` is unique per test method (available since bats 1.5.0, auto-cleaned by bats).

`cleanup_sandbox(dir)` tears down resources for a specific project dir using test helper name derivation functions — no prefix-based sweep, no production code. Called in three places:

- `ensure_test_isolation` — precautionary, before the test runs (covers interactive debugging where teardown didn't complete).
- `cleanup_test_resources` / `teardown()` — normal cleanup after each test.
- `teardown_suite` — retains the old prefix-based sweep as a safety net for resources leaked by crashed tests that skipped teardown.

Proxy port 8080 does not collide across parallel sandboxes because each sandbox's proxy binds to its own gateway IP (`--listen-host`), not `0.0.0.0`.

pf anchors are flushed in both setup and teardown. Bridge interfaces and IPs can be reused by the container runtime, so stale pf rules from a previous test could match a new test's traffic. Flushing in setup guards against this.

## Consequences

- Tests are fully independent — safe for `bats --jobs`.
- Each test that builds gets its own image. Acceptable cost at current suite size; a shared pre-built image is a future optimization.
- `BATS_TEST_TMPDIR` changes on every run (random component), so stale resources from a previous serial run won't be found by the precautionary cleanup. This is fine — the safety-net sweep in `teardown_suite` catches those.
