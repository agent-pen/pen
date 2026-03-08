# 27. Copy pen source instead of git clone for tests

Date: 2026-03-08

## Status

Accepted

## Context

The E2E test harness needs a copy of the pen source tree in the test user's home directory. Two approaches were considered:

1. **`git clone --local`** — creates a proper git repo in the test user's home. Only includes committed changes.
2. **`cp -R`** — copies the entire working tree as-is, including uncommitted and staged changes.

## Decision

Use `cp -R` to copy the pen source tree to the test user's home directory. The copy is owned by the test user via `chown -R`.

## Consequences

- Uncommitted changes are tested immediately — no need to commit or stash before running tests. This is the primary motivation: the developer's working tree is the thing under test.
- No git dependency in the test user's environment.
- The copy includes untracked files (build artifacts, editor temp files), but this has no practical impact since pen doesn't inspect its own source directory at runtime.
