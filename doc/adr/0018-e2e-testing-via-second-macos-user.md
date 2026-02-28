# 18. End-to-end testing via a second macOS user

Date: 2026-02-28

## Status

Accepted

## Context

pen depends on macOS host primitives: Apple's `container` CLI (Virtualization Framework), the `pf` packet filter, and `mitmdump`. End-to-end tests must exercise all of these on a real macOS host.

Several isolation approaches were considered:

1. **Nested macOS virtualisation.** Run pen inside a macOS VM so tests cannot interfere with the developer's environment. This is not feasible — macOS does not support nested macOS virtualisation. This is a Virtualization Framework limitation that affects Apple Container, UTM, and tart equally. Nested Linux VMs inside a macOS VM are supported (M3+), but pen needs to start macOS VMs via Apple Container, which is not supported inside a macOS VM.

2. **Dedicated remote or secondary Mac host.** Run tests on a separate physical machine. This is technically sound but introduces significant coordination overhead (provisioning, network access, syncing the code under test) and cost that is disproportionate for a personal project.

3. **Second macOS user on the same host.** Create a temporary user (`pen-e2e-test-user`) on the developer's machine. Apple Container state (images, containers, networks) is scoped to `~/Library/Application Support/com.apple.container/` per user, so the test user gets a completely isolated container environment. pf anchors are scoped by project-path hash and coexist safely. The test user is torn down after tests complete.

## Decision

We will run end-to-end tests under a temporary macOS user (`pen-e2e-test-user`) on the same host machine.

Test user creation, setup, and teardown are managed by the test harness. The test harness pre-stages a temporary sudoers entry granting the test user passwordless sudo for the specific commands that `install.sh` requires (`chown`, `chmod`, `tee`, `visudo`, `rm` scoped to pen paths). This allows `install.sh` and `uninstall.sh` to run unmodified as the test user, fully exercising the install path. The temporary sudoers entry is cleaned up when the test user is torn down.

## Consequences

- pen's install must support multiple users on the same machine. The symlink and sudoers file must be per-user (see ADR 0019).
- `pen start` must be non-interactive. The interactive shell is provided by `pen shell`, which runs `pen start` as a prerequisite.
- Tests require macOS Tahoe (26.x+) with Apple Silicon. Standard GitHub Actions macOS runners may not yet offer this.
- The test user has a stable name (`pen-e2e-test-user`) so that the setup sudoers entry only needs to be created once. This avoids requiring a password on every test run.
