# 9. install-into-path

Date: 2026-02-12

## Status

Accepted

## Context

Developers should be able to access `pen` from directory on their machine.

## Decision

Provide an installation script that symlinks `./pen` into the host environment's path at `/usr/bin/local/pen`.

## Consequences

An uninstall script should be provided to remove `pen` from the host environment's path.
