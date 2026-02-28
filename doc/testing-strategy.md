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

## System-wide touchpoints

pen currently installs two system-wide resources that prevent two users from having independent installations simultaneously. Both must be changed before multi-user testing can work.

### `/usr/local/bin/pen` symlink

`install.sh` creates `sudo ln -sf $PEN_HOME/pen /usr/local/bin/pen`. Two users cannot both own this symlink.

**Required change:** install to `~/.local/bin/pen` instead (no sudo needed). The install script should verify `~/.local/bin` is on `PATH` and warn if not. ADR 0009 (install-into-path) must be superseded.

### `/etc/sudoers.d/pen`

`install.sh` writes a single sudoers file granting `$(whoami)` passwordless sudo for `pfctl-wrapper.sh`. A second user running `install.sh` overwrites this file, revoking the first user's grant.

**Required change:** use `/etc/sudoers.d/pen-$(whoami)` so entries coexist. Both `install.sh` and `uninstall.sh` must be updated.

### Resources that are already isolated

| Resource | Scope | Notes |
|----------|-------|-------|
| pf anchors (`com.apple/pen-*`) | Per-project path hash | Two users in different directories get different anchor names |
| `pfctl -E` | System-wide | Idempotent, harmless |
| `pfctl-wrapper.sh` ownership (root:wheel) | Per-clone | Each user's clone gets its own root:wheel wrapper |
| `~/.pen/sandboxes/` | Per-user via `$HOME` | No change needed |
| `.pen/` in project dir | Per-project | No change needed |

## The non-interactive `pen start` problem

`start.sh` ends with `container exec -it ... bash`, dropping into an interactive shell. This hangs in automated tests.

**Required change:** make `pen start` non-interactive — it starts the sandbox and returns. The interactive shell moves to `pen shell`, which runs `pen start` as a prerequisite. `pen exec` also runs `pen start` as a prerequisite.

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

The test user does not need to be an admin. The primary user pre-stages just enough for `install.sh` to run unmodified:

1. Clone pen into the test user's home:
   ```bash
   sudo -u "$TEST_USER" git clone --local "$(pwd)" "/Users/$TEST_USER/pen"
   ```

2. Grant the test user passwordless sudo for the commands `install.sh` needs:
   ```bash
   cat <<SUDOERS | sudo tee "/etc/sudoers.d/pen-e2e-test-user-setup" > /dev/null
   $TEST_USER ALL=(root) NOPASSWD: /usr/sbin/chown root\:wheel *
   $TEST_USER ALL=(root) NOPASSWD: /bin/chmod 755 *
   $TEST_USER ALL=(root) NOPASSWD: /bin/chmod 440 *
   $TEST_USER ALL=(root) NOPASSWD: /usr/bin/tee /etc/sudoers.d/pen-*
   $TEST_USER ALL=(root) NOPASSWD: /usr/sbin/visudo -cf /etc/sudoers.d/pen-*
   $TEST_USER ALL=(root) NOPASSWD: /bin/rm -f /etc/sudoers.d/pen-*
   SUDOERS
   sudo chmod 440 "/etc/sudoers.d/pen-e2e-test-user-setup"
   sudo visudo -cf "/etc/sudoers.d/pen-e2e-test-user-setup"
   ```

3. Ensure `~/.local/bin` is on the test user's PATH:
   ```bash
   sudo -u "$TEST_USER" bash -c '
     mkdir -p ~/.local/bin
     echo "export PATH=\$HOME/.local/bin:\$PATH" >> ~/.zprofile
   '
   ```

4. Run `install.sh` as the test user (exercises the full install path):
   ```bash
   run_as_test_user bash -c "cd ~/pen && ./install.sh"
   ```

### Teardown

```bash
# Clean up any running pen sandboxes under the test user first
sudo rm -f "/etc/sudoers.d/pen-$TEST_USER"
sudo rm -f "/etc/sudoers.d/pen-e2e-test-user-setup"
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

The Apple Container apiserver is a per-user launch agent. It requires an active launchd user domain. Three candidate mechanisms, in order of preference:

### Option A: `launchctl asuser` (recommended, needs validation)

```bash
TEST_UID=$(id -u "$TEST_USER")
run_as_test_user() {
  sudo launchctl asuser "$TEST_UID" sudo -u "$TEST_USER" "$@"
}
```

This executes within the test user's launchd domain, which should allow the apiserver to start on demand. **This needs experimental validation** — see open questions below.

### Option B: SSH to localhost (fallback)

Set up an SSH keypair for the test user and connect via `ssh $TEST_USER@localhost <command>`. SSH fully initialises the launchd domain. Downside: requires `sshd` to be running and SSH key setup in the test harness.

### Option C: `su -` with password (last resort)

```bash
echo "$TEST_PASSWORD" | sudo su - "$TEST_USER" -c "<command>"
```

Fragile across macOS versions. Not recommended.

### Helper functions

```bash
pen_run() {
  run_as_test_user bash -c "
    cd $TEST_PROJECT && \
    PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin \
    pen \"\$@\"
  " -- "$@"
}
```

## Test runner: bats-core

[bats-core](https://github.com/bats-core/bats-core) is the standard Bash testing framework. It provides `@test` blocks, `setup`/`teardown` hooks, TAP output, and assertion helpers (via bats-assert). Install with `brew install bats-core`.

### File layout

```
test/
  e2e/
    setup_suite.bash            # Suite-level: test user create/delete
    helpers/
      run_as.bash               # run_as_test_user, pen_run
      assertions.bash           # assert_pf_anchor_exists, etc.
    01_install.bats             # install.sh / per-user scoping
    02_init.bats                # pen init
    03_build.bats               # pen build
    04_lifecycle.bats           # pen start / stop / status / restart
    05_exec.bats                # pen exec
    06_egress.bats              # Egress control, hot-reload
    07_teardown.bats            # Cleanup verification
    fixtures/
      Dockerfile                # Minimal image for fast build tests
  run-e2e.sh                    # Top-level runner
```

Files are numbered to enforce execution order.

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

### OQ-1: Does the Container apiserver start under `launchctl asuser`?

If `sudo launchctl asuser <uid> sudo -u $TEST_USER container list` fails with a connection error, the apiserver did not auto-start. Fall back to SSH (Option B). This must be tested experimentally before committing to an execution mechanism.

### OQ-2: Does the test user need specific macOS groups?

With the pre-staging approach, the test user never calls `sudo` directly during install — the primary user handles all privileged ops. The test user only needs `sudo` for `pfctl-wrapper.sh` at runtime (via the per-user sudoers entry). This should work for a standard (non-admin) user, but needs verification.

### OQ-3: Docker Hub pulls during `pen build`

The default Dockerfile uses `FROM docker/sandbox-templates:claude-code`, which is large and may require Docker Hub auth. For build tests, use a minimal Dockerfile (e.g. `FROM alpine:latest`) in `test/e2e/fixtures/` to avoid this dependency.

### OQ-4: CI

These tests require a macOS host with Apple Silicon, macOS Tahoe (26.x+), and the Apple Container CLI. Standard CI macOS runners (GitHub Actions) may not yet offer Tahoe images. A self-hosted runner is the realistic path. Gate the workflow on `sw_vers -productVersion`.

## Implementation sequence

### Phase 1: Prerequisites (pen changes)

1. Change `install.sh`: use `~/.local/bin/pen` and `/etc/sudoers.d/pen-$(whoami)`
2. Change `uninstall.sh` to match
3. Write ADRs (done: ADR 0018 and ADR 0019)
4. Make `pen start` non-interactive; move shell to `pen shell`
5. Manual verification that two users can install pen on the same host

### Phase 2: Test infrastructure

6. Install bats-core (`brew install bats-core`)
7. Create `test/e2e/` directory structure
8. Implement `setup_suite.bash` (test user lifecycle)
9. Implement helpers (`run_as.bash`, `assertions.bash`)
10. Validate OQ-1 (apiserver auto-start mechanism)

### Phase 3: Test scenarios (incremental)

11. `01_install.bats`
12. `02_init.bats`
13. `03_build.bats` (with minimal test Dockerfile)
14. `04_lifecycle.bats`
15. `05_exec.bats`
16. `06_egress.bats`
17. `07_teardown.bats`

### Phase 4: CI

18. Write `test/run-e2e.sh` runner script
19. Configure CI workflow (self-hosted macOS runner)
