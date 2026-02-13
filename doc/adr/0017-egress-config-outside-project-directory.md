# 17. Egress config outside project directory

Date: 2026-02-13

## Status

Accepted

## Context

The egress allowlist files (`http-allowlist.txt` and `network-allowlist.txt`) were stored in `.pen/` inside the project directory. The project directory is mounted into the sandbox via `--volume`, making the allowlists writable from inside the sandbox. Since the HTTP allowlist is hot-reloaded every second ([ADR 16](doc/adr/0016-hot-reload-http-allowlist.md)), code running inside the sandbox could modify it to bypass egress controls in under a second. The network allowlist is only read at start time so is less immediately exploitable, but still should not be writable from within the sandbox.

## Decision

Egress config is stored in `$HOME/.pen/sandboxes/<container-name>/` on the host, outside the project directory that is mounted into the sandbox. `pen init` creates this directory and writes the allowlist files there. The project-root `.pen/` directory retains only runtime artifacts (PID files, logs) and is fully gitignored.

The `container-name` is the same deterministic identifier used for the container, network, and pf anchor (e.g. `pen-myproject-a1b2c3`).

## Consequences

The sandbox cannot modify its own egress rules. The allowlist files are only accessible from the host.

The allowlists are no longer visible in the project directory. Users edit them at `~/.pen/sandboxes/<container-name>/` instead.
