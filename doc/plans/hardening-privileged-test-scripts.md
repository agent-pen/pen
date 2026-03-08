# Hardening Privileged E2E Test Scripts

**Status:** Implemented (guards + ownership). Seatbelt sandboxing abandoned.

## Threat model

The e2e test scripts run as root via sudo. A bug or malicious edit could cause them to operate on the invoking user's account or files instead of the test user. We want defense-in-depth to limit the blast radius.

## Techniques evaluated

### 1. root:wheel ownership on leaf scripts — IMPLEMENTED

`develop.sh` chowns all leaf scripts and `target-user-guards.sh` to `root:wheel`. Since sudoers entries reference these scripts by path, an unprivileged user cannot modify them. This prevents tampering with scripts that run as root.

Limitation: only protects against modification of the scripts themselves, not against bugs in their logic.

### 2. Verification guard functions — IMPLEMENTED

`target-user-guards.sh` (root:wheel owned, sourced by all leaf scripts) provides:

- `ensure_correct_target_user` — checks the target username matches the expected hardcoded value (`pen-e2e-test-user`, composed from parts to resist bulk find-and-replace)
- `ensure_correct_target_user_and_uid` — additionally checks the target UID differs from the invoking user's UID
- `ensure_correct_target_path` — checks the path is under `/Users/pen-e2e-test-user` and does not contain the invoking user's name
- `run_as_test_user` — centralised hand-off via `launchctl asuser` + `sudo -i -u`, with guard checks

These are runtime checks that catch logic errors before dangerous operations execute.

### 3. Scoped sudoers — IMPLEMENTED

Each leaf script has its own sudoers entry (no blanket `NOPASSWD: ALL`). The test user only gets sudoers for `install.sh` and `uninstall.sh`. Unexpected sudo usage is caught as a test failure.

### 4. Single-responsibility leaf scripts — IMPLEMENTED

Each script does one thing (create user, copy data, add sudoers, etc.). This makes each script easier to audit and limits the scope of any individual sudoers entry.

### 5. macOS sandbox-exec (Seatbelt) — ABANDONED

Investigated restricting file writes from privileged scripts using `sandbox-exec`. See `doc/plans/sandbox-exec-e2e-hardening.md` for the full investigation.

**Why abandoned:** XPC sandbox inheritance causes system daemons (e.g. `trustd`) to inherit the sandbox profile unpredictably, breaking container apiserver startup and certificate validation. Multiple profile designs were tried; none worked reliably.

### 6. Time Machine snapshots before test runs — NOT YET EVALUATED

Take a local APFS snapshot before each test run so the system can be rolled back if a privileged script causes unintended damage:

```bash
tmutil localsnapshot
```

This is a safety net, not a prevention mechanism. Snapshots are cheap and fast on APFS. Could be added to `e2e-setup.sh` as a one-liner.

**Open question:** Does this interact well with user creation/deletion? `sysadminctl` modifies Open Directory, which may not be fully captured by APFS snapshots.

## Current stance

Guards (2) + ownership (1) + scoped sudoers (3) + single-responsibility (4) provide sufficient protection for test scripts. The scripts only operate on a dedicated test user with a hardcoded name, verified at runtime. Seatbelt sandboxing (5) is not worth the complexity given macOS XPC inheritance issues. Time Machine snapshots (6) may be worth adding later as a cheap safety net.
