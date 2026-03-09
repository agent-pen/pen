# 37. Per-file test isolation with independent project directories

Date: 2026-03-09

## Status

Accepted

Supercedes [34. Kill proxy in bats teardown to prevent test runner hang](0034-kill-proxy-in-bats-teardown-to-prevent-test-runner-hang.md)

## Context

pen's e2e tests run against a shared persistent environment — a real macOS user account with a real filesystem, container runtime, and network stack. This makes tests susceptible to cross-file state leakage.

Previously, a single `setup_suite` installed pen, created one shared test project directory, and ran `pen init` and `pen build` for all test files. A shared `teardown_suite` handled proxy cleanup. This created several problems:

- **Implicit preconditions.** Each test file depended on setup_suite and prior files having run successfully, but didn't declare or verify this.
- **Cascading failures.** A failure in one file (e.g. install/uninstall leaving pen uninstalled) broke all subsequent files with misleading errors.
- **Hidden state coupling.** `pen init` short-circuits when the sandbox config directory already exists. A shared project directory meant one file's init poisoned another file's — `pen init` would report "already initialized" and skip creating the `.pen/` runtime directory in a freshly wiped project.

## Decision

Each bats test file creates its own uniquely-named project directory and establishes its own preconditions. Each file that creates resources owns their cleanup via `teardown_file`.

Shared helpers in `test_helper.bash`:
- `create_test_project <dir>` — removes any prior directory, creates a fresh one, and cds into it.
- `cleanup_test_project <dir>` — kills the proxy if running (to release bats FDs, per ADR 0034) and removes the directory.

Each test file declares a `PROJECT_DIR` variable, calls `create_test_project` in `setup_file` (or the test body), and calls `cleanup_test_project` in `teardown_file`.

There is no `setup_suite.bash`. Bats file numbering controls execution order, but files do not depend on each other's side effects.

## Consequences

- A failure in one test file cannot cascade into another. Each file is self-sufficient.
- Adding a new test file requires only choosing a unique project directory name and establishing its own preconditions — no need to reason about shared state.
- Idempotent setup commands (like `install_pen`) run multiple times across files. This is acceptable given the test suite size. If it becomes a performance issue, individual commands can be guarded with checks (e.g. `command -v pen` before installing).
- The proxy PID file path is still duplicated between `cleanup_test_project` and production code (`common.sh`). If the PID file location changes, the test helper must be updated to match.
