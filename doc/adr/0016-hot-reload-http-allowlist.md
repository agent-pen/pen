# 16. Hot-reload HTTP allowlist

Date: 2026-02-13

## Status

Accepted

## Context

The HTTP proxy ([ADR 13](doc/adr/0013-mitmdump-for-dns-based-egress-control.md)) loads its allowlist once at startup. Changes to `.pen/http-allowlist.txt` while a sandbox is running require a full restart to take effect.

Restarting the sandbox is disruptive — it tears down the container, network, and firewall rules, losing any in-progress work that hasn't been saved to the mounted volume.

Options for detecting file changes:

- **kqueue** (`select.kqueue` with `EVFILT_VNODE`): Available in Python's stdlib on macOS. Eliminates polling but adds complexity — integrating with mitmproxy's asyncio loop requires boilerplate, and file deletion/recreation (common with atomic editor saves) invalidates the watched file descriptor, requiring re-open logic.
- **watchdog** (FSEvents wrapper): Clean API that handles edge cases, but introduces an external dependency.
- **Polling**: Check the file's modification time periodically. Simple and robust, but introduces a short delay between file change and detection.

## Decision

The mitmdump addon will poll the allowlist file's modification time once per second using an asyncio background task. When a change is detected, the allowlist is reloaded into memory. This runs on mitmproxy's existing event loop with no external dependencies, threads, or per-request file I/O.

If the file is missing, the allowlist is cleared (no hosts allowed) and a warning is logged. The warning is only logged once per transition to avoid log spam.

## Consequences

Changes to `.pen/http-allowlist.txt` take effect within one second without restarting the sandbox.

There is a one-second polling interval. This is acceptable for a configuration file that changes infrequently.
