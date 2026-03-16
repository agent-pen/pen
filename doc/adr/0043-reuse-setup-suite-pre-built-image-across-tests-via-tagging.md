# 43. Reuse setup-suite pre-built image across tests via tagging

Date: 2026-03-16

## Status

Accepted

## Context

The test suite runs with parallel execution (bats `--jobs`), but the dominant per-test cost is `container build`. Even with BuildKit layer caching, each invocation has startup and verification overhead. With 7+ concurrent builds, contention on BuildKit makes it worse and causes "container already exists: buildkit" races.

`setup_suite` already runs a full sandbox lifecycle via `verify_naming_contract` — including `pen build` — to verify that test helper name derivation matches production naming. The resulting image is immediately deleted during cleanup, forcing every subsequent test to rebuild from scratch.

## Decision

Keep the image built by `verify_naming_contract` and let tests reuse it via `container image tag`. The image ref is written to `/tmp/pen-test-prebuilt-image` during `setup_suite`. A new helper `ensure_pen_image_available` reads this file and tags the pre-built image into the test's sandbox namespace. `ensure_pen_project_initialised` calls this helper after `pen init`, so tests that call `pen build` find the target image already tagged — making BuildKit's work a near-instant no-op.

`cleanup_sandbox` accepts `--keep-image` so `verify_naming_contract` can tear down everything except the image without duplicating cleanup logic. `teardown_suite`'s prefix-based sweep deletes the pre-built image along with any leaked test resources. Per-test `cleanup_sandbox` calls (without `--keep-image`) delete only the tag, not the underlying image, because `container image delete <tag>` removes the reference — not the content — when other tags still point to the same image.

## Consequences

- Tests that call `pen build` benefit automatically — BuildKit detects the image is already present and skips the build.
- Tests that only need `pen init` (not `pen build`) also get the image pre-tagged, which is harmless — the tag is cleaned up in teardown.
- `setup_suite` no longer deletes the image, creating a dependency: tests assume `/tmp/pen-test-prebuilt-image` exists. `ensure_pen_image_available` guards this with an explicit error message if the file is missing.
- No test files were changed — the optimisation is entirely in test infrastructure helpers.
