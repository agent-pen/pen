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
    privileged/           # Leaf scripts run as root (root:wheel owned)
      create-test-user.sh
      delete-test-account.sh
      copy-container-data.sh
      copy-pen-source.sh
      add-test-sudoers.sh
      remove-test-sudoers.sh
    target-user-guards.sh  # Guard functions sourced by leaf scripts
  run-test-suite.sh        # Runs bats in the test user's Mach context
  e2e/
    test_helper.bash       # Assertion helpers
    01_happy_path.bats     # Full lifecycle: install → init → build → exec → stop → uninstall
```

Three-phase execution enables interactive debugging:
1. **Setup** (`test/libs/privileged/`): Create test user, copy container data, add scoped sudoers
2. **Run** (`test/run-test-suite.sh`): Execute bats in the test user's Mach context
3. **Teardown** (`test/libs/privileged/`): Delete test user, clean up

To debug interactively, run setup, drop into a test user shell with `./test-user-shell.sh`, investigate, then teardown.

## Execution model

The entire bats test suite runs inside the test user's Mach context via `launchctl asuser`. This means pen, mitmdump, container CLI, and pfctl-wrapper all run natively as the test user. All test user hand-offs go through `run_as_test_user` in `target-user-guards.sh`.

## Security of test scripts

Privileged test scripts use multiple layers of protection:

- **root:wheel ownership** on all leaf scripts — prevents unprivileged tampering
- **Guard functions** (`verify_target_user`, `verify_target_path`) — runtime checks prevent operating on wrong user or path
- **Scoped sudoers** — only specific scripts can run as root, no blanket sudo
- **Single-responsibility** — each leaf script does one thing, limiting blast radius

## Known issues

- **Cloudflare WARP conflicts with container DNS** — disable WARP before running tests
- **Launchd domains survive user deletion** — `delete-test-account.sh` runs `launchctl bootout user/<uid>` after deletion to clean up orphaned domains
- **Changing the test username requires a reboot** — the container apiserver caches per-UID state in memory
