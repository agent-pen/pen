# Test Design Principles

See `doc/testing-strategy.md` for test infrastructure (user isolation, runner, execution model). This document covers *what* to test and *how* to write assertions.

## Core principle: test observable behavior, not implementation details

Tests should assert what pen *does*, not how it's wired internally.

- **Bad**: assert a symlink targets a specific file. **Good**: `pen --help` works.
- **Bad**: assert a file is owned by root. **Good**: prove the test user cannot modify it.
- Minimize coupling to internal paths and file structures — they change; behavior contracts don't.

## When implementation coupling is unavoidable (security invariants)

Some security properties are silent failures — pen works fine but is insecure. These can't be tested through normal usage, so tests must inspect implementation details. For security, err on the side of brittleness — a test that breaks when privileges change is a feature, not a bug.

**Example**: install grants passwordless sudo for the pfctl wrapper. The test uses `sudo -l` (every user can list their own privileges) to enumerate NOPASSWD entries, then asserts:
1. Exactly one pen script has sudoers privileges (the pfctl wrapper).
2. That script is not writable by the test user.

The test deliberately fails if unexpected scripts gain privileges — this is the right trade-off for security-critical assertions.

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

Add custom assertions to `test/suite/assertions.bash`.

## Test file organization

- One file per command or concern, numbered for execution ordering.
- `setup_suite` runs `pen install` once for the entire suite.
- `01_install.bats` — install-specific assertions (security invariants). Does not run install itself.
- `99_uninstall.bats` — uninstall assertions (runs last; uninstall would break subsequent files).
- Files in between (02–98) test individual pen commands, each independent.
- No reliance on `setup_suite` for assertions — bats only supports assertions inside `@test` blocks.

**Setup helpers** layer preconditions declaratively in each file's `setup()`:
- `ensure_test_isolation` — tears down all pen resources by prefix and recreates the project directory. Every test file calls this.
- `ensure_pen_installed` — verifies pen is on PATH. A guard so failures are clear if `setup_suite` didn't run.
- `ensure_pen_project_initialised` — runs `pen init` in the project directory. Used by files that need an initialized project (e.g. build tests). Files that test `pen init` itself call it explicitly in the test body.

## Bats gotchas

- `[[ ! -v var ]]` in loaded helpers breaks test gathering (0 tests found, no error). Use `${var+x}` instead.
- `load` works at file top level in `.bats` files, but NOT in `setup_suite.bash` (not a `.bats` file — use `source`).
- `setup_suite.bash` is auto-discovered but helper functions defined there may not be in scope for tests — use a dedicated `test_helper.bash` loaded explicitly.
- FD 3 in bats writes directly to the terminal (bypasses capture) — useful for real-time output from slow commands.
