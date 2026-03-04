# Plan: Restructure E2E test execution into setup/run/teardown phases

## Context

The e2e test is blocked on mitmdump failing to bind to the container gateway IP. The likely cause: `pen start` (which spawns mitmdump as a background process) runs through a `sudo launchctl asuser $UID sudo -i -u $USER` chain, creating ambiguous process context for vmnet interface access. Restructuring so the entire test suite runs natively in the test user's Mach context should fix this and improve debuggability.

This also improves the debugging workflow: developers can run setup, drop into an interactive session as the test user, investigate issues, then teardown — rather than relying on bats output alone.

## Design

Split `test/run-e2e.sh` into three scripts:

| Script | Invoked as | Responsibility |
|--------|-----------|----------------|
| `test/e2e-setup.sh` | `sudo test/e2e-setup.sh` | Create test user, copy data, add scoped sudoers, start apiserver |
| `test/e2e-run.sh` | Called by run-e2e.sh or manually via `launchctl asuser` | Export PATH, run bats — runs as test user |
| `test/e2e-teardown.sh` | `sudo test/e2e-teardown.sh` | Delete test user, remove sudoers |
| `test/run-e2e.sh` | `sudo test/run-e2e.sh` | Convenience: setup → run → teardown with EXIT trap |

### `test/e2e-setup.sh`

Same as current `run-e2e.sh` up to `start_container_apiserver`, plus:
- Add scoped sudoers entry for test user: `install.sh` and `uninstall.sh` only (not blanket)
  ```
  pen-e2e-test-user ALL=(root) NOPASSWD: /Users/pen-e2e-test-user/pen-source/install.sh
  pen-e2e-test-user ALL=(root) NOPASSWD: /Users/pen-e2e-test-user/pen-source/uninstall.sh
  ```
  Sudoers filename: `/etc/sudoers.d/pen-<UID>-e2e-test` (follows `pen-<UID>` convention)
- Write env vars (`TEST_USER`, `TEST_UID`, `PEN_SOURCE`, `TEST_PROJECT`) to a state file (e.g., `/tmp/pen-e2e-state`) so teardown and manual debugging can read them without re-deriving
- Print helper command for interactive debugging:
  ```
  To debug: sudo launchctl asuser <UID> sudo -i -u pen-e2e-test-user
  ```

### `test/e2e-run.sh`

Runs as the test user (inside their Mach context). Minimal:
- Source state file for `PEN_SOURCE`, `TEST_PROJECT`
- `export PATH="$HOME/.local/bin:$PATH"`
- Export `PEN_SOURCE` and `TEST_PROJECT` for bats (tests cd in `setup()`)
- `exec bats "$PEN_SOURCE/test/e2e/"`

Invoked by `run-e2e.sh` via:
```bash
sudo launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" "$PEN_SOURCE/test/e2e-run.sh"
```

### `test/e2e-teardown.sh`

- Read state file for `TEST_USER`
- Delete e2e sudoers file (`/etc/sudoers.d/pen-<UID>-e2e-test`)
- Delete pen's runtime sudoers file (`/etc/sudoers.d/pen-<UID>`) if install.sh created one
- `sysadminctl -deleteUser`
- Remove state file

### `test/run-e2e.sh`

Thin wrapper:
```bash
trap "$PEN_HOME/test/e2e-teardown.sh" EXIT
"$PEN_HOME/test/e2e-setup.sh"
# run bats in test user's Mach context
source /tmp/pen-e2e-state
sudo launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" "$PEN_SOURCE/test/e2e-run.sh"
```

### `test/e2e/test_helper.bash`

Simplifies dramatically. No more `as_test_user` or `in_test_project` — we're already the test user. Keeps:
- `assert_success`
- `assert_output_contains`

### `test/e2e/01_happy_path.bats`

```bash
load test_helper

setup() {
  cd "$TEST_PROJECT"
}

@test "install pen" {
  run sudo "$PEN_SOURCE/install.sh"
  assert_success
}

@test "pen init" {
  run pen init
  assert_success
}

@test "pen build with fixture Dockerfile" {
  cp "$PEN_SOURCE/test/e2e/fixtures/Dockerfile.minimal" .pen/Dockerfile
  run pen build
  assert_success
}

@test "pen exec runs command in sandbox" {
  run pen exec whoami
  assert_success
  assert_output_contains "root"
}

@test "pen stop" {
  run pen stop
  assert_success
}

@test "uninstall pen" {
  run sudo "$PEN_SOURCE/uninstall.sh"
  assert_success
}
```

Note: `sudo ./install.sh` works because (a) the test user has a scoped sudoers entry for it, and (b) `$SUDO_USER` is automatically set to the test user by `sudo`.

### `develop.sh` changes

Update the sudoers entry to cover `run-e2e.sh`, `e2e-setup.sh`, and `e2e-teardown.sh` (all need root). Keep `root:wheel` ownership on all three.

### Real-time output

`launchctl asuser` inherits stdout/stderr without buffering. Bats writes TAP lines synchronously as each test completes. Output should stream in real-time. If it doesn't, we'll address it then.

## Files to modify

| File | Action |
|------|--------|
| `test/e2e-setup.sh` | Create |
| `test/e2e-run.sh` | Create |
| `test/e2e-teardown.sh` | Create |
| `test/run-e2e.sh` | Rewrite to thin wrapper |
| `test/e2e/test_helper.bash` | Simplify (remove `as_test_user`, `in_test_project`, `as_sudo_user`) |
| `test/e2e/01_happy_path.bats` | Simplify (direct pen calls) |
| `develop.sh` | Add sudoers entries for new scripts |

## Verification

1. `sudo ./develop.sh` — sets up sudoers for all test scripts
2. `sudo test/run-e2e.sh` — full run, should show TAP output streaming in real-time
3. Manual debug workflow:
   - `sudo test/e2e-setup.sh`
   - `sudo launchctl asuser <UID> sudo -i -u pen-e2e-test-user` (interactive shell)
   - `cd ~/test-project && pen start` (investigate mitmdump binding)
   - Exit, then `sudo test/e2e-teardown.sh`
