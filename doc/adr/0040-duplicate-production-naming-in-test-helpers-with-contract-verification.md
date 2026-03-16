# 40. Duplicate production naming in test helpers with contract verification

Date: 2026-03-16

## Status

Accepted

## Context

Per-test-method isolation (ADR 0039) requires test helpers to derive resource names (container, network, pf anchor, image, config dir) from the project directory path. The production naming logic lives in `common.sh`. Sourcing it would create a dependency on production code for test orchestration, violating the principle that production code is only the test subject, never test infrastructure.

## Decision

Test helpers (`test_sandbox_name`, `test_container_name`, `test_network_name`, `test_pf_anchor`, `test_sandbox_config_dir`) duplicate the production naming logic from `common.sh`. This duplication is intentional.

To catch divergence, `setup_suite` runs `verify_naming_contract` before any tests execute. It creates a temporary project directory, asserts all derived resource names don't exist yet (`assert_would_fail assert_*_exists` — proving both absence and that the assertions work), runs the full `pen init/build/exec` lifecycle, then asserts all resources exist with the expected names. If production naming changes without a corresponding update to the test helpers, the suite aborts immediately.

After cleanup, `assert_pf_anchor_not_exists` verifies the anchor flush actually worked, guarding the flush path against regressions.

## Consequences

- Test infrastructure has zero runtime dependency on production code.
- Naming divergence is caught before any tests run, not silently inherited.
- The `assert_would_fail` pattern eliminates the need for separate "not exists" assertions — one check proves both absence and assertion correctness.
- The contract verification adds one full sandbox lifecycle to suite startup time. Acceptable as a one-time cost.
