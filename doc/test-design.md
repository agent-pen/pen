# Test Design Principles

See `doc/testing-strategy.md` for test infrastructure (user isolation, runner, execution model). This document covers *what* to test and *how* to write assertions.

## Core principle: test observable behavior, not implementation details

Tests should assert what pen *does*, not how it's wired internally.

- **Bad**: assert a symlink targets a specific file. **Good**: `pen --help` works.
- **Bad**: assert a file is owned by root. **Good**: prove the test user cannot modify it.
- Minimize coupling to internal paths and file structures — they change; behavior contracts don't.

**Assert on state, not diagnostic text.** Log messages, progress output, and error wording are implementation details — they can change without changing behavior. Assert on actual state changes instead. For example, to verify a sandbox is reused across exec calls, don't check for absence of "Starting container..." in output — create a file inside the container and verify it persists on the next call.

**Rule out coincidental success.** An assertion that passes without the intended behavior actually working is worthless. Ask: could this pass for the wrong reason? `expect_success pen exec test -f "$path"` at a path that exists on both the host and the container proves nothing — it could be running on the host. `pen exec uname` returning `Linux` on a macOS host can only succeed inside the container.

## When implementation coupling is unavoidable (security invariants)

Some security properties are silent failures — pen works fine but is insecure. These can't be tested through normal usage, so tests must inspect implementation details. For security, err on the side of brittleness — a test that breaks when privileges change is a feature, not a bug.

**Example**: install grants passwordless sudo for the pfctl wrapper. The test uses `sudo -l` (every user can list their own privileges) to enumerate NOPASSWD entries, then asserts:
1. Exactly one pen script has sudoers privileges (the pfctl wrapper).
2. That script is not writable by the test user.

The test deliberately fails if unexpected scripts gain privileges — this is the right trade-off for security-critical assertions.

## One behavior per test

Each test should verify one coherent behavior at the granularity of the function under test. This may require multiple assertions — that's fine when they collectively verify a single behavior. But don't pack unrelated concerns into one test. Stdout passthrough, stderr passthrough, and exit code propagation are separate behaviors — separate tests. "Runs inside a container" and "project directory is mounted" are separate behaviors — separate tests.

When a test fails, the name alone should tell you what broke.

## Stable vs. unstable interfaces

**Stable** (safe to reference in tests):
- `pen` CLI commands and their output
- `~/.pen/sandboxes/` — user-facing, documented path
- `sudo -l` output — every user can list their own sudo privileges
- `penctl/commands/lib/pfctl-wrapper.sh` — the sole privileged script; deliberately coupled for security

**Unstable** (avoid in tests):
- Symlink targets within pen's internals
- Sudoers file contents (not readable by the test user without privilege escalation)

## Three-tier install testing strategy

1. **Functional effects** — tested implicitly through later pen commands (no dedicated install tests needed). If `pen init` works, install set up the CLI correctly.
2. **Security invariants** — small dedicated test file asserting exactly which scripts have sudo privileges and that they're tamper-proof. Deliberately brittle — fails if privileges change.
3. **User-facing paths** (`~/.pen/sandboxes/`) — reference directly in tests; they're part of pen's contract.

## Verify retrofitted tests catch failures

When adding a test for existing behavior, seeing it pass the first time proves nothing — the assertion might be wrong, too loose, or testing the wrong thing. After the first green run:

1. Make the simplest safe production code change that should cause the assertion to fail (e.g. comment out a `mkdir`, rename a path).
2. Predict how the test will fail (which assertion, what error message).
3. Run the test and verify it fails the way you predicted.
4. Undo the production code change.

If the test doesn't fail, or fails differently than expected, the test isn't guarding what you think it is.

## Custom assertions

Use custom assertions to replace low-level test mechanics with intent. Inline `stat`, `wc`, pipe chains, and manual `[[ ]] || { echo ...; return 1; }` blocks add noise — they describe *how* you're checking, not *what* you're checking. A well-named assertion like `assert_owned_by root "$path"` makes the test read as a specification and produces a clear error message on failure ("expected owner root, got pen-test-user: /path") without the test author wiring up error reporting each time.

**Assert specific values, not categories.** `assert_exit_code 42` catches more regressions than `expect_failure`. A command that exits 1 instead of 42 is a different bug — "non-zero" misses it.

Add custom assertions to `test/suite/assertions.bash`.

## Test file organization

- One file per command or concern, numbered for execution ordering.
- **Lead with the happy path.** The first test in a file should demonstrate the command's primary purpose. A reader should understand what the command does from the first `@test` alone.
- **Name tests for user-facing purpose, not mechanism.** "pen exec runs command in project-specific container" (purpose) over "pen exec can see the project directory" (mechanism).
- `setup_suite` runs `pen install` once for the entire suite.
- `01_install.bats` — install-specific assertions (security invariants). Does not run install itself.
- `99_uninstall.bats` — uninstall assertions (runs last; uninstall would break subsequent files).
- Files in between (02–98) test individual pen commands, each independent.
- No reliance on `setup_suite` for assertions — bats only supports assertions inside `@test` blocks.

**Per-test isolation model**: Each test method gets its own unique project directory (`${BATS_TEST_TMPDIR}/test-project`). Since sandbox identity is derived from the project path (container name, network, pf anchor, image, config dir), unique project dirs mean fully namespaced resources with no cross-test interference. This is a prerequisite for parallel execution with `bats --jobs`.

**Name derivation helpers** (`test_sandbox_name`, `test_container_name`, etc.) in `test_helper.bash` duplicate production naming logic intentionally — tests should not depend on production code. Contract tests in `02_naming.bats` verify these stay in sync with pen's actual resource names.

**Setup helpers** layer preconditions declaratively in each file's `setup()`:
- `ensure_test_isolation` — creates a unique project directory and does precautionary cleanup of stale resources for this test's project path. Every test file calls this.
- `ensure_pen_installed` — verifies pen is on PATH. A guard so failures are clear if `setup_suite` didn't run.
- `ensure_pen_project_initialised` — calls `ensure_pen_installed`, then runs `pen init`. Used by files that need an initialized project (e.g. build tests). Files that test `pen init` itself call `ensure_pen_installed` directly.
- `ensure_pen_project_built` — calls `ensure_pen_project_initialised`, then runs `pen build`. Used by files that need a built sandbox (e.g. exec tests).

Each higher-level helper calls its prerequisite, so `setup()` only needs a single `ensure_*` call (plus `ensure_test_isolation`).

**Teardown**: Every test file (except `01_install.bats` and `99_uninstall.bats`) defines `teardown()` calling `cleanup_test_resources`, which tears down resources for this test's project dir using test helper name functions. `teardown_suite` in `setup_suite.bash` provides a safety-net prefix-based sweep for resources leaked by crashed tests.

## Bats gotchas

- `[[ ! -v var ]]` in loaded helpers breaks test gathering (0 tests found, no error). Use `${var+x}` instead.
- `load` works at file top level in `.bats` files, but NOT in `setup_suite.bash` (not a `.bats` file — use `source`).
- `setup_suite.bash` is auto-discovered but helper functions defined there may not be in scope for tests — use a dedicated `test_helper.bash` loaded explicitly.
- FD 3 in bats writes directly to the terminal (bypasses capture) — useful for real-time output from slow commands.
