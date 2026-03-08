# 28. Harden privileged test scripts with guards and root ownership

Date: 2026-03-08

## Status

Accepted

## Context

E2E test scripts run as root via sudo to create/delete macOS users, copy files between home directories, and manage sudoers entries. A bug or malicious edit could cause them to operate on the invoking developer's account or files instead of the test user.

## Decision

Four complementary hardening measures protect the privileged test scripts:

### 1. root:wheel ownership

`develop.sh` chowns all privileged leaf scripts and `target-user-guards.sh` to `root:wheel`. Since sudoers entries reference these scripts by path, an unprivileged user cannot modify them.

### 2. Leaf scripts only source root-owned files

Scripts listed in sudoers must not source user-writable files — otherwise a user-writable dependency becomes a privilege escalation vector. All privileged leaf scripts in `test/libs/privileged/` source only `target-user-guards.sh`, which is itself `root:wheel` owned. No other files are sourced. This keeps the trusted code boundary clear: everything executing with root privileges is root-owned.

### 3. Runtime guard functions

`target-user-guards.sh` provides guards that run before any dangerous operation:

- `ensure_correct_target_user` — verifies the target username matches the expected hardcoded value (composed from parts to resist bulk find-and-replace).
- `ensure_correct_target_user_and_uid` — additionally checks the target UID differs from the invoking user's UID.
- `ensure_correct_target_path` — verifies the path is under `/Users/pen-test-user` and does not contain the invoking user's name.

### 4. Single-responsibility leaf scripts

Each privileged script does one thing (create user, copy data, add sudoers, etc.) with its own sudoers entry. This makes each script easy to audit and limits the scope of any individual privilege grant.

## Consequences

- A bug in one leaf script cannot affect resources outside its narrow scope.
- Unprivileged users cannot modify scripts that run as root.
- Guard functions catch logic errors (wrong user, wrong path) at runtime before dangerous operations execute.
- The root-owned-only sourcing rule means adding a new shared helper for privileged scripts requires updating `develop.sh` to chown it. This is deliberate friction.
- No protection against bugs in the guard logic itself — but the guards are small, auditable, and rarely change.
