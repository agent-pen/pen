# 29. Abandon sandbox-exec for test script hardening

Date: 2026-03-08

## Status

Accepted

## Context

We investigated using macOS `sandbox-exec` (Seatbelt) to restrict file writes from privileged E2E test scripts as defense-in-depth on top of guards and root:wheel ownership (ADR 0028). The idea: leaf scripts re-exec themselves under `sandbox-exec` with a profile denying file writes outside expected targets.

Three profile designs were tried:

1. **Parameterised profile** — `(deny file-write* (subpath (param "DENY_HOME")))` with `-D DENY_HOME=/Users/$SUDO_USER`. Failed because XPC services (e.g. `trustd`) inherit the sandbox profile but NOT the `-D` parameter bindings. `(param "DENY_HOME")` resolves to empty string in the inherited context, causing `(subpath "")` to deny all file writes system-wide.

2. **Hardcoded paths** — eliminated `-D` params, used `(deny file-write* (subpath "/Users"))` with `(allow file-write* (subpath "/Users/pen-test-user"))`. `trustd` was still denied writes to the test user's keychain — the allow rule doesn't survive XPC inheritance or interacts unpredictably with the service's own sandbox profile.

3. **Tiered profiles** — three profiles matched to script needs with increasing scope. Same `trustd` failures, plus `(deny file-write*)` blocks `/dev/null`, pipes, and temp dirs, requiring a large system-path allowlist that erodes the deny-all intent.

The root cause is that macOS XPC services inherit Seatbelt profiles from their clients. This is undocumented, unpredictable, and unavoidable for scripts that trigger system services (user creation, certificate validation, container apiserver).

## Decision

Abandon Seatbelt sandboxing for E2E test scripts. The existing hardening (ADR 0028) — root:wheel ownership, guard functions, scoped sudoers, single-responsibility scripts, and root-only sourcing — provides sufficient protection.

## Consequences

- No kernel-level file write restrictions on privileged test scripts. Defense relies on application-level guards and ownership controls.
- Avoids a brittle dependency on undocumented macOS sandbox inheritance behaviour.
- If macOS ever documents or stabilises XPC sandbox inheritance semantics, this decision could be revisited.
