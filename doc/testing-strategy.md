# End-to-End Testing Strategy

## Why not VMs?

pen requires macOS host primitives: Apple's `container` CLI (Virtualization Framework), the `pf` packet filter, and `mitmdump`. The obvious isolation approach — running pen inside a macOS VM — is not feasible because **macOS does not support nested macOS virtualisation**.

## Approach: second macOS user

Run e2e tests under a dedicated macOS user (`pen-test-user`) on the same host machine. This provides full isolation from the developer's pen installation while retaining access to real host primitives (pf, Virtualization Framework, mitmdump). After tests complete, the test user and all its state are torn down.

Apple Container is per-user — images, containers, networks, and volumes are scoped to `~/Library/Application Support/com.apple.container/`. The test user gets a completely separate container environment.

## Test runner

[bats-core](https://github.com/bats-core/bats-core) provides `@test` blocks, `setup`/`teardown` hooks, and TAP output. Install with `brew install bats-core`.

## Test structure

```
test/
  libs/
    privileged/              # Leaf scripts run as root (root:wheel owned)
      create-test-user.sh
      delete-test-account.sh
      copy-container-data.sh
      copy-pen-source.sh
      grant-test-privileges.sh
      remove-test-sudoers.sh
      run-test-suite.sh       # Runs bats in the test user's Mach context
      shell-test-user.sh      # Interactive shell for debugging
    target-user-guards.sh     # Guard functions sourced by leaf scripts
  suite/
    setup_suite.bash       # Runs install once for the entire suite
    test_helper.bash       # Assertion, isolation, and setup helpers
    clear-pf-anchors.sh   # Privileged: flush pf anchors for invoking user
    01_install.bats        # Install security invariants
    02_init.bats           # pen init
    03_build.bats          # pen build (default and custom Dockerfile)
    98_happy_path.bats     # Full lifecycle: init → build → exec → stop
    99_uninstall.bats      # Uninstall (runs last)
```

Three-phase execution enables interactive debugging:
1. **Setup** (`test/libs/privileged/`): Create test user, copy container data, add scoped sudoers
2. **Run** (`test/run-test-suite.sh`): Execute bats in the test user's Mach context
3. **Teardown** (`test/libs/privileged/`): Delete test user, clean up

To debug interactively, run setup, drop into a test user shell with `./test-user-shell.sh`, investigate, then teardown.

## Per-test isolation

Every test starts from a clean slate. Each test file defines a `setup()` function that calls `ensure_test_isolation` from `test_helper.bash`. This tears down all pen resources (containers, networks, images, proxy processes, pf anchors, sandbox config directories) by matching the name prefix `pen-user-<uid>-project-`, then recreates the project directory. Tests never depend on state from prior tests, even within the same file. See [ADR 0038](adr/0038-per-test-isolation-via-setup.md).

Cleanup uses prefix-based matching against the container CLI's JSON output rather than mirroring pen's internal name derivation. This avoids coupling tests to implementation details.

Helpers layer preconditions declaratively:
- `ensure_test_isolation` — clean slate + fresh project directory
- `ensure_pen_installed` — verify pen is on PATH
- `ensure_pen_project_initialised` — run `pen init` in the project directory

## Execution model

The entire bats test suite runs inside the test user's Mach context via `launchctl asuser`. This means pen, mitmdump, container CLI, and pfctl-wrapper all run natively as the test user. All test user hand-offs go through `run_as_test_user` in `target-user-guards.sh`.

## Security of test scripts

Privileged test scripts use multiple layers of protection:

- **root:wheel ownership** on all leaf scripts — prevents unprivileged tampering
- **Guard functions** (`verify_target_user`, `verify_target_path`) — runtime checks prevent operating on wrong user or path
- **Scoped sudoers** — only specific scripts can run as root, no blanket sudo
- **Single-responsibility** — each leaf script does one thing, limiting blast radius

## Known issues

- **No parallel test runs** — `./test.sh` creates and tears down a shared test user account. Running multiple instances concurrently causes races (e.g. container-not-found errors). Always wait for one run to finish before starting another.
- **Cloudflare WARP conflicts with container DNS** — disable WARP before running tests
- **Launchd domains survive user deletion** — `delete-test-account.sh` runs `launchctl bootout user/<uid>` after deletion to clean up orphaned domains
- **Changing the test username requires a reboot** — the container apiserver caches per-UID state in memory
