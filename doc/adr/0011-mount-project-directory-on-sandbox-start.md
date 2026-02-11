# 11. mount project directory on sandbox start

Date: 2026-02-12

## Status

Accepted

## Context

Developers need the ability to read and write project files (e.g. source code) from within the sandbox associated with the project directory. This should not require any manual effort to configure.

There should be minimal friction in referring to project directory file paths across the host and sandbox environments.

## Decision

When starting a sandbox, automatically mount the associated host environment directory at the same path inside the sandbox. 

## Consequences

Project directory files are not protected from damaging operations executed inside the sandbox.