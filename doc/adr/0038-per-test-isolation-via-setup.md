# 38. Per-test isolation via setup

Date: 2026-03-15

## Status

Accepted

Supercedes [37. Per-file test isolation with independent project directories](0037-per-file-test-isolation-with-independent-project-directories.md)

## Context

ADR 0037 gave each test file its own project directory and lifecycle, preventing cross-file state leakage. However, tests within the same file still shared state — a container, network, image, or proxy left behind by one test could affect the next. This made test ordering significant and failures hard to diagnose.

Additionally, each test file duplicated boilerplate: declaring a `PROJECT_DIR`, wiring up `setup_file`/`teardown_file`, and managing cleanup of pen internals (proxy PID files, container names). The cleanup logic coupled tests to pen's internal name derivation.

## Decision

Every test gets a clean slate via bats `setup()`. A single shared helper, `ensure_test_isolation`, runs before each test and tears down all pen resources by name prefix (`pen-user-<uid>-project-`), then recreates the project directory. This eliminates inter-test dependencies even within the same file.

A single shared helper, `ensure_test_isolation`, tears down all containers, networks, images, proxy processes, pf anchors, and sandbox config directories matching the prefix, then recreates the project directory and cds into it.

Test files no longer declare `PROJECT_DIR`, `setup_file`, or `teardown_file`. Each file's `setup()` calls `ensure_test_isolation` plus whichever precondition helpers it needs. Tests that exercise `pen init` call it explicitly in the test body rather than relying on setup.

Cleanup uses prefix-based matching against the container CLI's JSON output rather than mirroring pen's name derivation logic. This avoids coupling tests to implementation details.

## Consequences

- Tests within the same file are fully independent. Reordering or running a single test in isolation produces the same result.
- No `setup_file`/`teardown_file` boilerplate. Adding a new test file requires only `setup()` with the appropriate `ensure_*` helpers.
- `ensure_test_isolation` runs before every test, which is slower than per-file setup. Acceptable at current suite size; if it becomes a bottleneck, expensive steps (like image deletion) could be made conditional.
- The proxy PID file duplication from ADR 0037 is eliminated — `pkill -f mitmdump` replaces PID file management.
- A new privileged script (`clear-pf-anchors.sh`) is required for pf anchor cleanup, granted via `grant-test-privileges.sh`. It is scoped to the invoking user's UID via `SUDO_UID`.
