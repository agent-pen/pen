# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See `README.md` for an overview of pen, prerequisites, installation, and usage. See `TODO.md` for the project backlog.

There are no tests, linters, or build steps for pen itself.

## Architecture

**CLI dispatch**: `pen` resolves subcommands by walking `penctl/commands/` as a directory tree. A command like `pen proxy logs` maps to `penctl/commands/proxy/logs.sh`. The `lib/` directory is excluded from dispatch and contains shared functions and helpers sourced by commands.

**Sandbox identity**: Container, network, and image names are deterministically derived from the project directory path using a hash, ensuring one sandbox per directory.

**Network egress model**: Two layers, both default-deny:
1. **pf firewall** (host-side): Allows container-to-subnet, DNS, and proxy traffic. Additional IP:port pairs from the network allowlist get individual pass rules. Everything else is blocked. Each container gets its own pf anchor.
2. **HTTP proxy** (host-side): mitmdump addon that checks `(hostname, port)` against the HTTP allowlist. TLS passes through without termination; blocking happens at the CONNECT level.

**Egress config location**: Allowlist files are stored in `$HOME/.pen/sandboxes/<container-name>/` on the host, outside the project directory that is mounted into the sandbox. This prevents the sandbox from modifying its own egress rules. The project-root `.pen/` directory contains only runtime artifacts (PID files, logs).

**Privileged operations**: A single dedicated wrapper script has passwordless sudo for pf operations. It is scoped to pen-specific anchors and only supports flush and load.

**Sudoers entries must only reference leaf scripts.** Scripts listed in sudoers are chowned to `root:wheel` to prevent tampering. For this to be effective, those scripts must not source user-writable files — otherwise a user-writable dependency becomes a privilege escalation vector. Keep sudoers-listed scripts self-contained with single, tightly-scoped responsibilities and hardcoded parameters (e.g. usernames) so they cannot be repurposed.

## Conventions

- All scripts use `set -o nounset -o errexit -o pipefail`.
- Uses Apple's `container` CLI (not `docker`) for VM operations.
- Architecture decisions are recorded as ADRs in `doc/adr/` managed with the [`adr` CLI tool](https://github.com/npryce/adr-tools). Create new ADRs with `adr new "Title"`. To supersede an existing ADR: `adr new -s <number> "Title"`.
- Per-project egress config (allowlists) lives in `$HOME/.pen/sandboxes/<container-name>/`. Runtime artifacts (PID, logs) live in `.pen/` within the user's project directory.
- **Structure scripts with well-named functions.** Use function names to convey intent rather than relying on section comments. The main block at the bottom should read as a high-level summary of what the script does.
- **Working principle: simplest next step.** Bias for action over speculation. Get to the simplest working version as fast as possible, then iterate. Let each small step reveal the next blocker. Speculation is fine during planning, but implementation should drive out the simplest solution. Refactor to manage complexity later — avoid bloated solutions from speculated dependencies.
- **Git commands:** Execute each git command as its own Bash tool call (not chained with `&&` or `;`), so the user can configure persistent permissions for each command independently.
- **Document important principles in source-controlled files** (e.g. `CLAUDE.md`) rather than in auto-memory, so they persist long-term and are visible to all contributors.
