# 22. Bats for end-to-end testing

Date: 2026-03-01

## Status

Accepted

## Context

pen is implemented entirely in Bash (ADR 0005). The E2E tests (ADR 0018) exercise pen commands end-to-end under a temporary macOS user, running shell commands and checking their output and exit codes.

We need a test framework that fits naturally into this shell-native workflow without introducing a language runtime dependency.

## Decision

We will use [bats-core](https://github.com/bats-core/bats-core) as the test runner. Test files live in `test/e2e/` and are numbered to enforce execution order. A root-level orchestrator (`test/run-e2e.sh`) manages the test user lifecycle and invokes bats.

## Consequences

- Tests are written in Bash, consistent with the project.
- bats provides `@test` blocks, `setup`/`teardown` hooks, `run` capturing, and TAP output with no additional runtime.
- bats-core is a dev-only dependency, installed via `Brewfile.dev`.
