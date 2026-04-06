# 47. Retain test user across development runs

Date: 2026-04-06

## Status

Accepted

## Context

Every `./test.sh` run created and deleted a macOS user account via `sysadminctl`, adding ~15 seconds of overhead. During local development this overhead dominates short test runs and discourages frequent iteration.

The test user lifecycle was tightly coupled: `setup.sh` always deleted any existing user then created a fresh one, and `teardown.sh` always deleted the user on exit. There was no way to retain the user between runs.

Separately, test cleanup relied on `delete-test-account.sh` to both kill processes and delete the account in a single step. Process cleanup (killing containers, proxies, flushing pf anchors) could not be performed independently of account deletion.

## Decision

Introduce `PEN_TEST_FRESH_USER=1` as an opt-in environment variable for full user recreation. When unset (the default), the test user is retained across runs. The pre-commit hook sets this flag so commits always get full isolation.

Key changes:

1. **`clean-test-user-processes.sh`**: Extracted from `delete-test-account.sh` as a standalone privileged script that kills all test user processes and flushes pf anchors without deleting the account. This enables state cleanup independent of user lifecycle.

2. **`teardown.sh` restructured**: Always runs `remove-test-sudoers.sh` and `clean-test-user-processes.sh`. Only runs `delete-test-account.sh` when `PEN_TEST_FRESH_USER=1`.

3. **`setup.sh` calls `teardown.sh` first**: Cleans up state from the previous run (including crashed runs), then creates the user only if it doesn't already exist.

4. **`teardown_suite` stops the container system and removes the pen symlink**: Ensures the bats-level cleanup leaves no running services or installed pen binary, without relying on production `uninstall.sh`.

5. **`setup_suite` calls `teardown_suite` first**: Catches stale in-suite resources from crashed previous runs before installing pen and running tests.

6. **rsync for source and container data copies**: `copy-pen-source.sh` and `copy-container-data.sh` use `rsync -a --delete` instead of `cp -R`, making re-copies fast no-ops when content hasn't changed. This means `configure-test-env.sh` always runs regardless of mode — no conditional skip needed.

## Consequences

- Local `./test.sh` runs skip the ~15s user creation/deletion cycle when the test user already exists.
- The pre-commit hook and CI always get full user recreation via `PEN_TEST_FRESH_USER=1`.
- If the test user doesn't exist (first run, or after a fresh-user run), it is created automatically — no separate setup step needed.
- `clean-test-user-processes.sh` is a new privileged script. Developers must re-run `./develop.sh` to update their sudoers after pulling this change.
- Container data (kernels, BuildKit cache) is only copied on first user creation. If the host user's container data changes, a `PEN_TEST_FRESH_USER=1` run is needed to refresh it.
- System agents like `distnoted` may respawn after process cleanup via launchd. These are harmless and get killed again on the next run's teardown.
