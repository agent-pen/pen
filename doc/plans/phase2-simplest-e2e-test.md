# Plan: Simplest Working E2E Test Run

## Context

Phase 1 (pen changes for testability) is complete. The proof-of-concept (`test/e2e/validate-oq1.sh`) validates that `launchctl asuser` works. Now we need the simplest path to a real bats test passing end-to-end.

## Changes

### 1. Add working principle to `CLAUDE.md`

Add to the Conventions section:

> **Working principle: simplest next step.** Bias for action over speculation. Get to the simplest working version as fast as possible, then iterate. Let each small step reveal the next blocker. Speculation is fine during planning, but implementation should drive out the simplest solution. Refactor to manage complexity later — avoid bloated solutions from speculated dependencies.

### 2. Create `Brewfile` (base dependencies for end users)

```ruby
brew "jq"
cask "mitmproxy"
# TODO: Add Apple "container" — needs investigation re: conflict with direct installs
```

### 3. Create `Brewfile.dev` (dev-only dependencies)

```ruby
brew "bats-core"
```

### 4. Create `development.sh` — one-time dev machine setup

Run with `sudo`. Installs Homebrew deps and sets up passwordless sudo for test runs. Responsibilities:
- Install base + dev Homebrew dependencies (as `$SUDO_USER`)
- Add sudoers entry for passwordless `test/run-e2e.sh`

### 5. Create `test/run-e2e.sh` — orchestrator (run with `sudo`)

Evolve from `validate-oq1.sh`. Responsibilities:
- Require root
- Defensive cleanup of leftover test user
- Create test user (`sysadminctl -addUser`, then `createhomedir -c -u`)
- Copy container kernel from invoking user to test user
- Clone pen into test user's home (`git clone --local`)
- Export `TEST_USER`, `TEST_UID`, `TEST_PROJECT`
- Run `bats test/e2e/`
- Tear down test user on exit (`trap cleanup EXIT`)

**No .zprofile manipulation.** PATH is set explicitly in the `pen_run` helper when running pen commands.

### 6. Create `test/e2e/setup_suite.bash` — bats suite helpers

Define helper functions available to all .bats files:
- `run_as_test_user()` — wraps `sudo launchctl asuser $TEST_UID sudo -u $TEST_USER "$@"`
- `pen_run()` — runs pen in the test project dir with explicit PATH including `~/.local/bin`

Reads `TEST_USER`, `TEST_UID`, `TEST_PROJECT` from environment (set by run-e2e.sh).

### 7. Create `test/e2e/01_install.bats` — first test

Single test case:
- `@test "install.sh creates symlink and sudoers entry"` — runs `sudo SUDO_USER=$TEST_USER ./install.sh` in the cloned pen dir, asserts `~/.local/bin/pen` symlink and `/etc/sudoers.d/pen-<user>` file exist.

### 8. Update `TODO.md`

- Add: investigate adding Apple `container` CLI to Brewfile (compatibility with existing direct installs unknown)
- Add: `development.sh` sudoers entry for passwordless `test/run-e2e.sh` execution (deferred — just use `sudo` for now)

## Files to create/modify

| File | Action |
|------|--------|
| `CLAUDE.md` | Edit — add working principle |
| `Brewfile` | Create — base dependencies |
| `Brewfile.dev` | Create — dev dependencies (includes base) |
| `development.sh` | Create — one-time dev setup |
| `test/run-e2e.sh` | Create — orchestrator |
| `test/e2e/setup_suite.bash` | Create — bats helpers |
| `test/e2e/01_install.bats` | Create — first test |
| `TODO.md` | Edit — add Brewfile TODO |

## Verification

1. Run `sudo ./development.sh` — installs bats-core and other deps, sets up passwordless sudo
2. Run `sudo test/run-e2e.sh` — should produce TAP output with 1 passing test
3. Confirm test user is cleaned up: `id pen-e2e-test-user` should fail
