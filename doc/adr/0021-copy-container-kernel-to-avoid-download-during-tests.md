# 21. Copy container data to avoid downloads during tests

Date: 2026-03-01

## Status

Accepted

## Context

Apple Container downloads a ~450MB Linux kernel on first use per user. It also downloads a ~100MB BuildKit image on first `container build`. The E2E test harness (ADR 0018) creates a fresh macOS user for each run, so every test run would trigger both downloads, adding minutes of wall time and network dependency.

The developer running the tests already has both at `~/Library/Application Support/com.apple.container/` — the kernel under `kernels/` and BuildKit under `content/`.

## Decision

The test setup (`copy-container-data.sh`) copies both `kernels/` and `content/` from the invoking user's container data directory to the test user's equivalent directory before running any pen commands. Absolute symlinks (e.g. the `default.kernel-arm64` symlink) are rewritten to point to the test user's paths.

The entire `~/Library/Application Support/com.apple.container/` tree is chowned to the test user, including intermediate directories, so that `container system start` can create the apiserver socket.

## Consequences

- Test runs avoid ~550MB of downloads, keeping cycle time short.
- Tests do not require network access for kernel or BuildKit acquisition.
- If the invoking user is missing either directory, the copy is skipped with a warning and the download happens transparently at runtime (with a one-time slow first run).
- Kernel symlinks use absolute paths, so they must be rewritten when copying between users — `copy-container-data.sh` handles this automatically.
