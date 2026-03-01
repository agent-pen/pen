# 21. Copy container kernel to avoid download during tests

Date: 2026-03-01

## Status

Accepted

## Context

Apple Container downloads a ~450MB Linux kernel on first use per user. The E2E test harness (ADR 0018) creates a fresh macOS user for each run, so every test run would trigger this download, adding minutes of wall time and network dependency.

The developer running the tests already has the kernel at `~/Library/Application Support/com.apple.container/kernels/`.

## Decision

The test orchestrator (`test/run-e2e.sh`) copies the kernel from the invoking user's container kernel directory to the test user's equivalent directory before running any pen commands.

## Consequences

- Test runs avoid a several-hundred-MB download, keeping cycle time short.
- Tests do not require network access for kernel acquisition.
- If the invoking user has no kernel (fresh machine), the copy is skipped and `container system start --enable-kernel-install` handles it transparently (with a one-time slow download).
