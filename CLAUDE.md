# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See `README.md` for an overview of pen, prerequisites, installation, and usage. See `TODO.md` for the project backlog.

## Testing

See `doc/test-design.md` for test design principles and `doc/testing-strategy.md` for test infrastructure. Run the full e2e suite with `./test.sh`.

A pre-commit hook runs the full test suite on every commit.

**Strict TDD.** All functional changes must be test-driven:
1. Write the simplest possible test to drive the next tiny increment of functionality. Work backwards from the assertion.
2. Predict how the test will fail.
3. Run the test to verify it fails that way.
4. Implement only the code that addresses the immediate failure — nothing more. Do not batch fixes across multiple assertions. If a test has two assertions and the first fails, fix only that. Run again. Let the second assertion fail. Then fix that. Every assertion must get at least one verified failure before being made to pass.
5. Run the test to verify. If it reveals a new failure, return to step 2.

## Architecture

**CLI dispatch**: `pen` resolves subcommands by walking `penctl/commands/` as a directory tree. A command like `pen proxy logs` maps to `penctl/commands/proxy/logs.sh`. The `lib/` directory is excluded from dispatch and contains shared functions and helpers sourced by commands.

**Sandbox identity**: Container, network, and image names are deterministically derived from the project directory path using a hash, ensuring one sandbox per directory.

**Network egress model**: Two layers, both default-deny:
1. **pf firewall** (host-side): Allows container-to-subnet, DNS, and proxy traffic. Additional IP:port pairs from the network allowlist get individual pass rules. Everything else is blocked. Each container gets its own pf anchor.
2. **HTTP proxy** (host-side): mitmdump addon that checks `(hostname, port)` against the HTTP allowlist. TLS passes through without termination; blocking happens at the CONNECT level.

**Egress config location**: Allowlist files are stored in `$HOME/.pen/sandboxes/<container-name>/` on the host, outside the project directory that is mounted into the sandbox. This prevents the sandbox from modifying its own egress rules. The project-root `.pen/` directory is source-controlled and may contain user config (e.g. a custom Dockerfile). Runtime artifacts (PID files, logs) are gitignored within it.

**Privileged operations**: A single dedicated wrapper script has passwordless sudo for pf operations. It is scoped to pen-specific anchors and only supports flush and load.

**Sudoers entries must only reference leaf scripts.** Scripts listed in sudoers are chowned to `root:wheel` to prevent tampering. For this to be effective, those scripts must not source user-writable files — otherwise a user-writable dependency becomes a privilege escalation vector. Keep sudoers-listed scripts self-contained with single, tightly-scoped responsibilities and hardcoded parameters (e.g. usernames) so they cannot be repurposed.

## Conventions

- All scripts use `set -o nounset -o errexit -o pipefail`.
- Uses Apple's `container` CLI (not `docker`) for VM operations.
- Architecture decisions are recorded as ADRs in `doc/adr/` managed with the [`adr` CLI tool](https://github.com/npryce/adr-tools). Create new ADRs with `adr new "Title"`. To supersede an existing ADR: `adr new -s <number> "Title"`.
- Per-project egress config (allowlists) lives in `$HOME/.pen/sandboxes/<container-name>/`. The project-root `.pen/` directory is source-controlled; runtime artifacts (PID, logs) are gitignored within it.
- **Working principle: simplest next step.** Bias for action over speculation. Get to the simplest working version as fast as possible, then iterate. Let each small step reveal the next blocker. Speculation is fine during planning, but implementation should drive out the simplest solution. Refactor to manage complexity later — avoid bloated solutions from speculated dependencies.
- **Git commands:** Execute each git command as its own Bash tool call (not chained with `&&` or `;`), so the user can configure persistent permissions for each command independently. Run git commands without `-C` flags — assume the working directory is the repo root.
- **Document important principles in source-controlled files** (e.g. `CLAUDE.md`) rather than in auto-memory, so they persist long-term and are visible to all contributors.
- See `doc/code-design.md` for code design principles.

## Automated Code Review

A PostToolUse hook (`.claude/hooks/post-commit-review-gate.sh`) fires after every `git commit`. If the commit message does not contain `[automated subagent code review]`, the agent is reminded to invoke the code-reviewer subagent. The hook is lightweight — all review work happens in the subagent.

The code-reviewer subagent (`.claude/agents/code-reviewer.md`) reviews all changed files (except `.md`) against the project's design principles (`doc/code-design.md`, `doc/test-design.md`). It reads full files (not just diffs), performs mutation testing on new/modified tests, and detects retrofitted tests. The reviewer reports findings but does not fix them — the agent presents findings to the user, who decides what to address.

When committing fixes from code review, include `[automated subagent code review]` in the commit message to skip re-review. Only use this marker for commits that address code review findings — never to skip review for convenience.
