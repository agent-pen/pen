# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See `README.md` for an overview of pen, prerequisites, installation, and usage. See `TODO.md` for the project backlog.

There are no tests, linters, or build steps for pen itself.

## Architecture

**CLI dispatch**: `pen` resolves subcommands by walking `penctl/commands/` as a directory tree. A command like `pen proxy logs` maps to `penctl/commands/proxy/logs.sh`. The `lib/` directory is excluded from dispatch and contains shared functions and helpers sourced by commands.

**Sandbox identity**: Container, network, and image names are deterministically derived from the project directory path using a hash, ensuring one sandbox per directory.

**Network egress model**: Two layers, both default-deny:
1. **pf firewall** (host-side): Allows container-to-subnet, DNS, and proxy traffic. Additional IP:port pairs from `.pen/network-allowlist.txt` get individual pass rules. Everything else is blocked. Each container gets its own pf anchor.
2. **HTTP proxy** (host-side): mitmdump addon that checks `(hostname, port)` against `.pen/http-allowlist.txt`. TLS passes through without termination; blocking happens at the CONNECT level.

**Privileged operations**: A single dedicated wrapper script has passwordless sudo for pf operations. It is scoped to pen-specific anchors and only supports flush and load.

## Conventions

- All scripts use `set -o nounset -o errexit -o pipefail`.
- Uses Apple's `container` CLI (not `docker`) for VM operations.
- Architecture decisions are recorded as ADRs in `doc/adr/` managed with the [`adr` CLI tool](https://github.com/npryce/adr-tools).
- Per-project config lives in `.pen/` within the user's project directory (not in this repo).
