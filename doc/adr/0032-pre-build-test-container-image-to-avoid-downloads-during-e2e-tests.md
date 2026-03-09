# 32. Pre-build test container image to avoid downloads during e2e tests

Date: 2026-03-09

## Status

Accepted

## Context

The e2e test suite builds a container image during `pen build`. Previously, the test Dockerfile (`FROM alpine:latest`) required the test user to download the Alpine base image and install packages (`apk add`), both of which need network access and add significant latency to each test run.

The test setup already copies the invoking user's container `kernels/` and `content/` directories to the test user, but did not copy `state.json` — the container system's image registry. Without `state.json`, the container system didn't know that image blobs already present in `content/` were available, so it re-downloaded them.

Additionally, the BuildKit builder image (~100MB) was fetched on first `container build` per user, adding further startup delay.

## Decision

Split the test Dockerfile into two files:

1. **`Dockerfile.test-minimal-build`** — the real build (`FROM alpine`, `RUN apk add ...`). Built once by `develop.sh` on the developer's machine, tagged as `pen-test-minimal`.
2. **`Dockerfile.minimal`** — used by the test suite. Contains only `FROM pen-test-minimal`, making `pen build` a no-op image layer copy with no network access needed.

`develop.sh` runs `container system start` and `container build -t pen-test-minimal` during dev setup, ensuring both the BuildKit builder image and the `pen-test-minimal` image exist in the developer's container content store.

`copy-container-data.sh` now also copies `state.json` alongside `kernels/` and `content/`, so the test user's container system recognises all pre-cached images without re-downloading.

## Consequences

- Test runs no longer require network access for the build step, eliminating download latency and flakiness from transient DNS errors (e.g. Cloudflare WARP conflicts).
- `develop.sh` must be re-run when the test Dockerfile changes, to rebuild `pen-test-minimal`.
- The developer's `state.json` is copied wholesale to the test user, which includes entries for the developer's own pen images. These are harmless — the blobs exist in the copied `content/` directory, and the test user's own builds overwrite the relevant entries.
