# 30. Bootout launchd domain after test user deletion

Date: 2026-03-08

## Status

Accepted

## Context

The Apple Container apiserver is a launchd agent registered in the per-user `user/<uid>` domain. When a macOS user is deleted with `sysadminctl -deleteUser`, the process is killed but the launchd domain — and all its registered services — persist. A new user assigned the same UID inherits this stale domain, which causes `container system start` to hang or behave unpredictably.

The domain persists because macOS launchd domains auto-materialize on demand. Even after account deletion, any XPC message targeting `user/<uid>` causes launchd to lazily instantiate an empty domain and bootstrap system agents into it.

## Decision

`delete-test-account.sh` runs `launchctl bootout user/<uid>` unconditionally after deleting the account. This tears down the entire user domain including the container apiserver, network, and core-images services.

Two ordering constraints:

1. **Bootout after deletion.** If run while the account still exists, the valid UID causes launchd to re-bootstrap system agents immediately, repopulating the domain.
2. **No pre-check.** `launchctl print user/<uid>` would re-materialize the domain via lazy instantiation, defeating the purpose. The bootout runs unconditionally and ignores errors.

## Consequences

- The container apiserver's launchd services are fully cleaned up between test runs, preventing stale state from causing hangs.
- If a previous test run was interrupted after account deletion but before bootout, the orphaned domain cannot be cleaned up without a reboot. This is acceptable for that edge case.
- Changing the test username also requires a reboot — the apiserver caches per-UID state in memory that survives user deletion but not reboot.
