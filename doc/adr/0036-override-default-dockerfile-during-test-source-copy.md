# 36. Override default Dockerfile during test source copy

Date: 2026-03-09

## Status

Accepted

Supercedes [32. Pre-build test container image to avoid downloads during e2e tests](0032-pre-build-test-container-image-to-avoid-downloads-during-e2e-tests.md)

## Context

ADR 32 introduced a two-file approach for test container images: `Dockerfile.test-minimal-build` (the real build, run once by `develop.sh`) and `Dockerfile.minimal` (a `FROM pen-test-minimal` one-liner copied into `.pen/Dockerfile` by each test). This worked but meant the happy path test used a per-project override Dockerfile rather than the default `penctl/image/Dockerfile` path, so it never exercised the default build path.

## Decision

Eliminate `Dockerfile.minimal` as a test fixture. Instead, `copy-pen-source.sh` overwrites `penctl/image/Dockerfile` in the copied source with `FROM pen-test-minimal` during test environment setup. The happy path test now runs `pen build` without copying any fixture, exercising the default Dockerfile path.

`develop.sh` still pre-builds `pen-test-minimal` from `Dockerfile.test-minimal-build` as before.

## Consequences

- The happy path test exercises the real default build path (`penctl/image/Dockerfile`), not a per-project override.
- One fewer test fixture file to maintain.
- The override happens in a privileged script (`copy-pen-source.sh`) which already has root access for the source copy — no additional privilege escalation needed.
- Future tests for per-project Dockerfile override behaviour can still copy a fixture to `.pen/Dockerfile` independently.
