# 26. Strip inherited environment for test user execution

Date: 2026-03-08

## Status

Accepted

## Context

The test suite runs via a chain of `launchctl asuser <uid> sudo -i -u <test-user>` (ADR 0025). Without intervention, the root/dev user's environment leaks into the test user's session — `PATH`, Homebrew variables, editor settings, and other shell state. This causes two problems:

1. **False passes.** Tests succeed because leaked `PATH` entries (e.g. `/opt/homebrew/bin`) provide binaries that should only be available if the test user's own profile is correct.
2. **False failures.** Leaked variables interfere with pen's behaviour in ways that wouldn't occur for a real user.

The test user needs a clean, predictable environment that mirrors what a real user would have after login.

## Decision

All test user hand-offs go through `run_as_test_user` in `target-user-guards.sh`, which uses `env -i` to strip the inherited environment before switching to the test user:

```bash
launchctl asuser "$target_uid" env -i TERM="$TERM" LANG="$LANG" sudo -i -u "$target" "$@"
```

Only `TERM` (terminal type) and `LANG` (locale) are passed through — both are needed for correct terminal behaviour and are non-sensitive. `sudo -i` then rebuilds the environment from the test user's login shell profile.

The test user's `.zprofile` is created by `create-test-user.sh` with the minimal PATH needed:

```bash
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
```

This is necessary because `/etc/paths.d/` on macOS has no Homebrew entry — `path_helper` alone won't find `bats` or `pen`.

## Consequences

- Tests run in a clean environment that matches what a real user would see after login.
- Environment leakage from the dev user (e.g. Homebrew paths, editor variables) cannot cause false passes.
- The `.zprofile` makes the test user's PATH explicit and auditable rather than relying on inherited state.
- If pen needs additional environment variables to function, they must be set in pen's own code or the test user's profile — they won't be silently inherited.
