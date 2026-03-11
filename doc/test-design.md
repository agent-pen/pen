# Test Design Principles

See `doc/testing-strategy.md` for test infrastructure (user isolation, runner, execution model). This document covers *what* to test and *how* to write assertions.

## Core principle: test observable behavior, not implementation details

Tests should assert what pen *does*, not how it's wired internally.

- **Bad**: assert a symlink targets a specific file. **Good**: `pen --help` works.
- **Bad**: assert a file is owned by root. **Good**: prove the test user cannot modify it.
- Minimize coupling to internal paths and file structures — they change; behavior contracts don't.

## When implementation coupling is unavoidable (security invariants)

Some security properties are silent failures — pen works fine but is insecure. These can't be tested through normal usage, so tests must inspect implementation details. Strategy: couple to the *minimum stable interface* needed.

**Example**: install creates sudoers-referenced scripts owned by `root:wheel`. Rather than hardcoding the pfctl-wrapper path:
1. Couple to `/etc/sudoers.d/pen-$UID` — this is a system convention, unlikely to change.
2. Parse the sudoers file to discover which scripts it references.
3. Assert those scripts' security properties (ownership, permissions, not user-writable).

This way, if pen renames or moves the wrapper, the test still works — it follows the sudoers file to whatever scripts are referenced.

## Stable vs. unstable interfaces

**Stable** (safe to reference in tests):
- `pen` CLI commands and their output
- `~/.pen/sandboxes/` — user-facing, documented path
- `/etc/sudoers.d/pen-$UID` — system convention

**Unstable** (avoid in tests):
- Internal file paths like pfctl-wrapper location
- Symlink targets within pen's internals
- Specific sudoers syntax beyond what's needed to extract file paths

## Three-tier install testing strategy

1. **Functional effects** — tested implicitly through later pen commands (no dedicated install tests needed). If `pen init` works, install set up the CLI correctly.
2. **Security invariants** — small dedicated test file with minimal coupling via sudoers parsing. These are the silent-failure properties that can't be caught by usage.
3. **User-facing paths** (`~/.pen/sandboxes/`) — reference directly in tests; they're part of pen's contract.

## Test file organization

- One file per command or concern, numbered for execution ordering.
- Each file is self-contained: calls `install_pen` in its own `setup_file()`.
- `01_install.bats` — install assertions including security invariants (runs first so failures surface early).
- `99_uninstall.bats` — uninstall assertions (runs last; uninstall would break subsequent files).
- Files in between (02–98) test individual pen commands, each independent.
- No reliance on `setup_suite` for assertions — bats only supports assertions inside `@test` blocks.

## Bats gotchas

- `[[ ! -v var ]]` in loaded helpers breaks test gathering (0 tests found, no error). Use `${var+x}` instead.
- `load` works at file top level in `.bats` files, but NOT in `setup_suite.bash` (not a `.bats` file — use `source`).
- `setup_suite.bash` is auto-discovered but helper functions defined there may not be in scope for tests — use a dedicated `test_helper.bash` loaded explicitly.
- FD 3 in bats writes directly to the terminal (bypasses capture) — useful for real-time output from slow commands.
