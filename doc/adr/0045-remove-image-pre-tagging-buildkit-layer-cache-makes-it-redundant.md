# 45. Remove image pre-tagging — BuildKit layer cache makes it redundant

Date: 2026-03-16

## Status

Accepted

Supercedes [43. Reuse setup-suite pre-built image across tests via tagging](0043-reuse-setup-suite-pre-built-image-across-tests-via-tagging.md)

## Context

ADR 0043 introduced image pre-tagging: `setup_suite` preserved the image built during `verify_naming_contract`, and a helper (`ensure_pen_image_available`) re-tagged it into each test's sandbox namespace before `pen build`. The intent was to make BuildKit skip the build entirely when the target tag already existed.

Empirical testing showed this has no effect. BuildKit's layer cache is content-addressed — keyed on (Dockerfile instruction + base image digest), not on the target tag. With the test Dockerfile reduced to `FROM pen-test-minimal` (ADR 0036) and the base image already in the content store (ADR 0021), every `container build` invocation gets a full cache hit regardless of whether the target image was pre-tagged. Timed runs with and without pre-tagging showed identical BuildKit output (`CACHED` on all steps) and no measurable time difference (~350ms either way).

## Decision

Remove the image pre-tagging mechanism:

- Delete `ensure_pen_image_available()` from `test_helper.bash`.
- Remove the `--keep-image` flag from `cleanup_sandbox()` — it always deletes the image now.
- Remove image ref persistence (`/tmp/pen-test-prebuilt-image`) from `setup_suite.bash`.
- `ensure_pen_project_initialised` calls `pen init` only.

## Consequences

- Test infrastructure is simpler: no cross-test image state, no temp file coordination, no conditional cleanup logic.
- `verify_naming_contract` does a full cleanup including the image, restoring symmetry between setup and teardown.
- Build performance is unchanged — the real caching comes from the `pen-test-minimal` base image (ADR 0036) and pre-copied container data (ADR 0021).
