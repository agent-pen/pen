# 48. Avoid BuildKit cold start between test runs

Date: 2026-04-06

## Status

Accepted

Supersedes [47. Retain test user across development runs](0047-retain-test-user-across-development-runs.md) (partially — refines the process cleanup strategy introduced there)

## Context

Timing instrumentation revealed that `container build` was the single largest cost in the test suite. Even with a pre-built `pen-test-minimal` image and a `FROM pen-test-minimal` Dockerfile override, `container build` took 6-7s on first invocation after the container system started (BuildKit cold start) and 2-3s on subsequent invocations (warm BuildKit).

Three mechanisms were forcing a cold BuildKit on every `./test.sh` run:

1. **`teardown_suite` stopped the container system.** The comment said "so the next run starts clean", but by this point all pen resources (containers, networks, images, proxies, pf anchors) had already been individually cleaned up. Stopping the system only killed the apiserver and BuildKit daemon, forcing a ~5s cold start on the next run.

2. **`teardown.sh` called `clean-test-user-processes.sh` unconditionally.** This ran `pkill -9 -u $TARGET_UID`, killing all test user processes including the container system. This was a safety net for crashed test runs, but `teardown_suite` already handles targeted cleanup of pen resources.

3. **`copy-container-data.sh` ran on every test run.** It rsynced the developer's container data (kernels, BuildKit cache) to the test user, which is only needed when creating a new test user. On retained-user runs the data was already in place.

Together these added ~5s of BuildKit cold-start overhead to `verify_naming_contract` in `setup_suite`, plus inflated `container build` times throughout the test suite.

## Decision

Keep the container system running between test runs when the test user is retained (the default). Specifically:

1. **Remove `container system stop` from `teardown_suite`.** The individual resource cleanup (containers, networks, images, proxies, pf anchors) is sufficient. The container system and BuildKit daemon stay warm for the next run.

2. **Remove the blanket process kill from `teardown.sh`.** `clean-test-user-processes.sh` is no longer called during normal teardown. Its logic (`force_kill_processes`, `flush_pf_anchors`) is merged back into `delete-test-account.sh`, where it is only needed before account deletion.

3. **Move `copy-container-data.sh` to user creation only.** Moved from `configure-test-env.sh` (which runs every time) into the `! id "$TEST_USER"` conditional in `setup.sh` (which runs only when creating a new user).

4. **Delete `clean-test-user-processes.sh`** and remove it from the `develop.sh` sudoers list.

## Consequences

- `container build` in `verify_naming_contract` drops from ~7s to ~2s on retained-user runs, since BuildKit is already warm.
- Developers must re-run `./develop.sh` to update their sudoers (removes the deleted script).
- If the developer's container data changes (e.g. rebuilding `pen-test-minimal`), a `PEN_TEST_FRESH_USER=1` run is needed to re-copy it to the test user.
- `PEN_TEST_FRESH_USER=1` and pre-commit hook runs still get full process cleanup and fresh state via `delete-test-account.sh`.
- If a test run crashes badly enough that `teardown_suite` doesn't run, stale processes (proxies, containers) may persist. The next run's `teardown_suite` handles these via prefix-based resource cleanup. The container system staying alive is benign — it consumes minimal resources and gets reused.
