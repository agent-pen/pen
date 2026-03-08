# End-to-End Testing Strategy

## Why not VMs?

pen requires macOS host primitives: Apple's `container` CLI (Virtualization Framework), the `pf` packet filter, and `mitmdump`. Testing pen end-to-end means running it on a real macOS host.

The obvious isolation approach — running pen inside a macOS VM — is not feasible. pen starts Linux VMs via Apple Container. Testing pen from within a macOS VM would require a nested macOS VM (to host pen) running a nested Linux VM (the sandbox). **macOS does not support nested macOS virtualisation.** This is a Virtualization Framework limitation that affects Apple Container, UTM, and tart equally.

Nested *Linux* VMs inside a macOS VM are supported (M3+ with `container run --virtualization`), but pen itself requires macOS, so a Linux guest cannot host the test.

## Chosen approach: second macOS user

Run e2e tests under a dedicated macOS user (`pen-e2e-test-user`) on the same host machine. This provides:

- **Full isolation** from the developer's pen installation, containers, images, and networks.
- **Real host primitives** — pf, Virtualization Framework, and mitmdump all work normally.
- **No nested virtualisation** — the test user runs pen directly on the host.

After tests complete, the temporary user and all its state are torn down.

## Apple Container is per-user

Confirmed: the `container` CLI stores all data under `~/Library/Application Support/com.apple.container/` and runs a per-user launch agent (`com.apple.container.apiserver`). Images, containers, networks, and volumes are scoped to the calling macOS user. The test user gets a completely separate container environment with no visibility into the developer's containers.

### Launchd domains and container apiserver state survive user deletion

The container apiserver (`com.apple.container.apiserver`) is a launchd agent registered in the per-user `user/<uid>` domain. When a macOS user is deleted with `sysadminctl -deleteUser`, the process is killed but the launchd domain — and all its registered services — persist. A new user assigned the same UID inherits this stale domain, which can cause `container system start` to hang or exhibit unpredictable behaviour.

**Why the domain persists:** macOS launchd domains auto-materialize on demand. Even after account deletion, any XPC message targeting `user/<uid>` (including `launchctl print`) causes launchd to lazily instantiate an empty domain and bootstrap system agents into it. The domain is tied to the UID number, not the account record.

**Fix:** `delete-test-account.sh` runs `launchctl bootout user/<uid>` after deleting the account. This tears down the entire user domain including the container apiserver, network, and core-images services. The bootout runs unconditionally without checking first — `launchctl print` would re-materialize the domain via lazy instantiation, defeating the purpose.

**Ordering matters:** the bootout must happen *after* account deletion. If run while the account still exists, the valid UID causes launchd to re-bootstrap system agents immediately, repopulating the domain.

**Gap:** if a previous test run was interrupted after account deletion but before bootout, the orphaned domain can't be cleaned up (no account means `id -u` can't resolve the UID). This requires a reboot. Acceptable for this edge case.

**Also note:** changing the test username requires a reboot. The apiserver caches per-UID state in memory that survives user deletion but not reboot. If the username changes (even at the same UID), `container system start` hangs because the launchd service has stale in-memory state from the old username.

## System-wide touchpoints — RESOLVED

Both system-wide conflicts have been resolved:

- **`~/.local/bin/pen` symlink**: `install.sh` now installs per-user (no `/usr/local/bin`). See ADR 0019.
- **`/etc/sudoers.d/pen-$USER`**: Per-user sudoers files coexist. `install.sh` requires `sudo` and uses `$SUDO_USER` internally.

### Resources that are already isolated

| Resource | Scope | Notes |
|----------|-------|-------|
| pf anchors (`com.apple/pen-*`) | Per-project path hash | Two users in different directories get different anchor names |
| `pfctl -E` | System-wide | Idempotent, harmless |
| `pfctl-wrapper.sh` ownership (root:wheel) | Per-clone | Each user's clone gets its own root:wheel wrapper |
| `~/.pen/sandboxes/` | Per-user via `$HOME` | No change needed |
| `.pen/` in project dir | Per-project | No change needed |

## The non-interactive `pen start` problem — RESOLVED

`pen start` is now non-interactive — it starts the sandbox and returns. The interactive shell moved to `pen shell`. Both `pen shell` and `pen exec` auto-start as a prerequisite.

## Test user lifecycle

### Create

```bash
TEST_USER="pen-e2e-test-user"
TEST_PASSWORD="$(openssl rand -hex 16)"

sudo sysadminctl -addUser "$TEST_USER" \
  -fullName "pen test user" \
  -password "$TEST_PASSWORD" \
  -home "/Users/$TEST_USER" \
  -createHomeDirectory
```

### Setup (run by the primary user with sudo)

The test user does not need to be an admin. `install.sh` and `uninstall.sh` require `sudo` and use `$SUDO_USER` internally to resolve the real user, so the test harness runs them via `sudo` on behalf of the test user.

1. Clone pen into the test user's home:
   ```bash
   sudo -u "$TEST_USER" git clone --local "$(pwd)" "/Users/$TEST_USER/pen"
   ```

2. Ensure `~/.local/bin` is on the test user's PATH:
   ```bash
   sudo -u "$TEST_USER" bash -c '
     mkdir -p ~/.local/bin
     echo "export PATH=\$HOME/.local/bin:\$PATH" >> ~/.zprofile
   '
   ```

3. Run `install.sh` as the test user (exercises the full install path):
   ```bash
   sudo SUDO_USER="$TEST_USER" bash -c "cd /Users/$TEST_USER/pen && ./install.sh"
   ```

### Teardown

```bash
# Clean up any running pen sandboxes under the test user first
sudo rm -f "/etc/sudoers.d/pen-$TEST_USER"
sudo sysadminctl -deleteUser "$TEST_USER" -secure
```

The `-secure` flag deletes the home directory. Omit it to preserve state for debugging failed runs.

Teardown must run even on test failure. Use `trap teardown EXIT` in the test runner.

Defensive cleanup at suite start handles interrupted previous runs:

```bash
setup_suite() {
  cleanup_test_user_if_exists   # idempotent
  create_test_user
  ...
}
```

## Executing commands as the test user

The Apple Container apiserver is a per-user launch agent. It requires an active launchd user domain. `launchctl asuser` sets the Mach bootstrap context; validated via `test/e2e/validate-oq1.sh`.

### Execution model: full Mach context switch

The entire bats test suite runs inside the test user's Mach context — not individual commands. This means pen, mitmdump, container CLI, and pfctl-wrapper all run natively as the test user, avoiding process context mismatches.

The orchestrator (`test/run-e2e.sh`) invokes bats via:
```bash
sudo launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" "$PEN_SOURCE/test/e2e-run.sh"
```

Inside `e2e-run.sh`, PATH is set and bats is `exec`'d. Tests call `pen` directly — no wrappers needed.

For `install.sh`/`uninstall.sh` (which require `sudo`), the test user has scoped sudoers entries created by `e2e-setup.sh`. No blanket sudo — only the specific scripts are allowed, so unexpected sudo usage is caught.

See `doc/plans/phase2b-test-execution-restructure.md` for the full design.

## Test runner: bats-core

[bats-core](https://github.com/bats-core/bats-core) is the standard Bash testing framework. It provides `@test` blocks, `setup`/`teardown` hooks, TAP output, and assertion helpers (via bats-assert). Install with `brew install bats-core`.

### File layout

```
test/
  run-e2e.sh                    # Convenience: setup → run → teardown
  e2e-setup.sh                  # Create test user, copy data, sudoers (runs as root)
  e2e-run.sh                    # Export PATH, exec bats (runs as test user)
  e2e-teardown.sh               # Delete test user, clean up (runs as root)
  e2e/
    test_helper.bash            # assert_success, assert_output_contains
    01_happy_path.bats          # Full lifecycle: install → exec → uninstall
    fixtures/
      Dockerfile.minimal        # Minimal image for fast build tests
```

Files are numbered to enforce execution order. The three-script split (`e2e-setup.sh` / `e2e-run.sh` / `e2e-teardown.sh`) enables a manual debugging workflow: run setup, drop into an interactive test user session, investigate, then teardown.

## Test scenarios

### Install (`01_install.bats`)

- `install.sh` creates `~/.local/bin/pen` symlink
- `install.sh` does not touch `/usr/local/bin/pen`
- Per-user sudoers file exists at `/etc/sudoers.d/pen-$TEST_USER`
- Two users can install pen without overwriting each other's sudoers
- `uninstall.sh` removes per-user symlink and sudoers

### Init (`02_init.bats`)

- `pen init` creates `~/.pen/sandboxes/<container-name>/`
- Creates `http-allowlist.txt` with default entries
- Creates `network-allowlist.txt`
- Creates `.pen/` in the project directory
- Appends `/.pen/` to `.gitignore`
- Is idempotent

### Build (`03_build.bats`)

- `pen build` creates a container image named after the project
- Custom Dockerfile in `.pen/Dockerfile` is used when present

Note: build tests are slow (Docker Hub pull). Use a minimal test Dockerfile from `test/e2e/fixtures/` where possible. Tag slow tests for optional exclusion.

### Lifecycle (`04_lifecycle.bats`)

- `pen status` exits 1 when not running
- `pen start` starts the container and returns
- `pen status` exits 0 when running
- `pen stop` stops the container
- `pen stop` removes the pf anchor, container network, and proxy process
- `pen restart` creates a new container

### Exec (`05_exec.bats`)

- `pen exec echo hello` outputs "hello"
- `pen exec bash -c "exit 42"` returns exit code 42

### Egress control (`06_egress.bats`)

- HTTP request to an allowed host succeeds
- HTTP request to a blocked host is rejected
- Hot-reload: adding a host to the allowlist makes it accessible without restart
- Hot-reload: removing a host blocks it without restart
- pf blocks direct traffic that bypasses the proxy (e.g. `nc -z <ip> 443`)

### Cleanup (`07_teardown.bats`)

- No leftover containers after `pen stop`
- No leftover networks after `pen stop`
- No leftover pf anchor rules after `pen stop`
- No leftover proxy process after `pen stop`
- Container image is still present (expected — images are reused)

## Open questions

### OQ-1: Does the Container apiserver start under `launchctl asuser`? — RESOLVED

**Yes.** Validated experimentally. The full working chain is:

```bash
TEST_UID=$(id -u "$TEST_USER")
launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" container system start --enable-kernel-install
launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" container list
```

Caveats discovered during validation:
- `sysadminctl -addUser -createHomeDirectory` does not actually create the home directory. Use `createhomedir -c -u "$TEST_USER"` after user creation.
- `container system start` is handled transparently by pen (via `ensure_container_system` in `common.sh`) using `--enable-kernel-install`, which is a no-op when the kernel is already present. To avoid the ~450MB kernel download on every test run, the test harness copies the kernel from the invoking user's `~/Library/Application Support/com.apple.container/kernels/` to the test user's equivalent directory before running any pen commands.
- macOS may show a TCC "administer your computer" prompt when `sysadminctl` creates/deletes users from a terminal app. This appears intermittently (possibly related to script content changes). Clicking "Don't Allow" still allows the test to pass (with a `-14120` error logged). On headless CI runners this prompt does not appear.

### OQ-2: Does the test user need specific macOS groups? — PARTIALLY RESOLVED

The test user calls `sudo` for three things, all via scoped NOPASSWD sudoers entries:
1. `install.sh` — granted by `e2e-setup.sh`
2. `uninstall.sh` — granted by `e2e-setup.sh`
3. `pfctl-wrapper.sh` — granted by `install.sh` (runs as a test step)

No admin group membership or blanket sudo required. Standard (non-admin) user should work, but needs verification.

### OQ-3: Docker Hub pulls during `pen build`

The default Dockerfile uses `FROM docker/sandbox-templates:claude-code`, which is large and may require Docker Hub auth. For build tests, use a minimal Dockerfile (e.g. `FROM alpine:latest`) in `test/e2e/fixtures/` to avoid this dependency.

**TODO:** The BuildKit image (~100MB) is downloaded on every test run because it's per-user and the test user is recreated each time. Copy it during `e2e-setup.sh` alongside kernels/content to avoid this repeated download.

### OQ-4: CI

These tests require a macOS host with Apple Silicon, macOS Tahoe (26.x+), and the Apple Container CLI. Standard CI macOS runners (GitHub Actions) may not yet offer Tahoe images. A self-hosted runner is the realistic path. Gate the workflow on `sw_vers -productVersion`.

## Implementation sequence

### Phase 1: Prerequisites (pen changes) — DONE

1. ~~Change `install.sh`: use `~/.local/bin/pen` and `/etc/sudoers.d/pen-$(whoami)`~~
2. ~~Change `uninstall.sh` to match~~
3. ~~Write ADRs (done: ADR 0018, 0019, 0020)~~
4. ~~Make `pen start` non-interactive; `pen shell` and `pen exec` auto-start~~
5. ~~Require `sudo` for `install.sh`/`uninstall.sh`; use `$SUDO_USER` internally~~
6. ~~Auto-start container system transparently via `ensure_container_system`~~
7. Manual verification that two users can install pen on the same host (deferred to Phase 2)

### Phase 2: Test infrastructure — IN PROGRESS

8. ~~Install bats-core (`brew install bats-core`)~~
9. ~~Create `test/run-e2e.sh` — root-level orchestrator~~
10. ~~Create `develop.sh` — one-time dev setup script~~
11. ~~Validate OQ-1 (apiserver auto-start mechanism)~~
12. Restructure into `e2e-setup.sh` / `e2e-run.sh` / `e2e-teardown.sh` — see `doc/plans/phase2b-test-execution-restructure.md`

Design decisions:

- **`install.sh` / `uninstall.sh` are test scenarios, not infrastructure.** They run inside the happy-path test, not in suite setup. This exercises the full install path as a test.
- **Bats runs in the test user's Mach context.** The entire test suite runs natively as the test user — no per-command `launchctl asuser` wrappers. This avoids process context mismatches (e.g., mitmdump failing to bind to vmnet interfaces).
- **Scoped sudoers for the test user.** Only `install.sh` and `uninstall.sh` are allowed — not blanket sudo. Unexpected sudo usage in pen will be caught as a test failure.
- **Three-script split enables debugging.** Run setup, drop into an interactive test user session, investigate, then teardown.
- **No `-createHomeDirectory` flag.** `sysadminctl -addUser` without it, then `createhomedir -c -u` separately (the flag is unreliable).
- **Passwordless execution via sudoers.** `develop.sh` adds a per-user sudoers entry for test scripts so developers never type a password to run tests.

### Sandbox hardening — abandoned

We investigated using macOS `sandbox-exec` (Seatbelt) to restrict what privileged e2e test scripts can write to, as defense-in-depth on top of `root:wheel` ownership and guard functions. The approach was for leaf scripts to re-exec themselves under `sandbox-exec` with a profile that denied file writes outside expected targets.

**Approaches tried:**

1. **Parameterised profile** — `(deny file-write* (subpath (param "DENY_HOME")))` with `-D DENY_HOME=/Users/$SUDO_USER`. Failed because XPC services (e.g. `trustd`) inherit the sandbox profile but NOT the `-D` parameter bindings. `(param "DENY_HOME")` resolves to empty string in the inherited context, causing `(subpath "")` to deny all file writes system-wide.

2. **Hardcoded paths, three profiles** — eliminated `-D` params entirely. Three profiles with increasing scope: deny-all-writes-except-test-user-home, deny-all-writes-except-sudoers, deny-writes-under-/Users. Even with hardcoded allow rules for `/Users/pen-e2e-test-user`, `trustd` was still denied writes to the test user's keychain. The inherited profile appears to lose allow overrides or interact unpredictably with the service's own sandbox. Additionally, `(deny file-write*)` blocks `/dev/null`, pipes, and temp dirs, requiring a large system-path allowlist.

**Root cause:** macOS XPC services inherit Seatbelt profiles from their clients. This is undocumented, unpredictable, and makes it impossible to sandbox scripts that trigger system services (user creation, certificate validation, container apiserver) without breaking those services.

**Existing mitigations (sufficient for test scripts):**
- `root:wheel` ownership on all leaf scripts and `test-user-guard.sh` — prevents unprivileged tampering
- `verify_target_user` / `verify_target_path` guards — prevent operating on wrong user or path
- Scoped sudoers — only specific scripts can run as root, no blanket sudo
- Hardcoded test username composed from parts — resistant to bulk find-and-replace attacks

### Phase 3: Test scenarios (incremental)

Start with a single happy-path test covering the full journey (install, build, start, exec, uninstall), then extend with scenario-specific tests (e.g. network control).

13. Happy-path end-to-end test
14. Network/egress control scenarios
15. Additional scenarios as needed

### Phase 4: CI

16. Configure CI workflow (self-hosted macOS runner)
