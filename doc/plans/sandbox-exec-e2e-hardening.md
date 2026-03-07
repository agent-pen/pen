# sandbox-exec E2E Hardening — Investigation & Abandonment

**Status:** Abandoned. XPC sandbox inheritance makes this unworkable for scripts that trigger system services.

## Goal

Use macOS `sandbox-exec` (Seatbelt) to restrict file writes from privileged e2e test scripts, preventing accidental writes to the invoking user's home directory or other unintended locations.

## Background

- `sandbox-exec` applies a Seatbelt profile to a process and all its children
- Profiles use SBPL (Sandbox Profile Language): `(version 1)`, `(allow default)`, `(deny file-write* ...)`
- `-D KEY=VALUE` passes parameters interpolated via `(param "KEY")`
- `sandbox-exec` is deprecated (removed from man pages) but functional through macOS Sequoia
- The underlying Seatbelt kernel mechanism is not deprecated

## Design: self-sandboxing leaf scripts

Leaf scripts re-exec themselves under `sandbox-exec`:

```bash
if [[ -z "${_PEN_SANDBOXED:-}" ]]; then
    export _PEN_SANDBOXED=1
    exec sandbox-exec -f "$SCRIPT_DIR/../sandbox-profiles/profile.sb" "$0" "$@"
fi
```

- `_PEN_SANDBOXED` env var prevents infinite re-exec loop
- Orchestrators call `sudo script.sh` (matches sudoers entries exactly)
- The sandbox is applied inside the already-elevated process
- `sudo` wrapping `sandbox-exec` breaks scoped sudoers (changes the command sudoers sees)
- `sandbox-exec` wrapping `sudo` doesn't work (Seatbelt blocks setuid execution)

## Attempt 1: Parameterised deny profile

```scheme
(version 1)
(allow default)
(deny file-write* (subpath (param "DENY_HOME")))
```

Invoked with `-D "DENY_HOME=/Users/$SUDO_USER"`.

**Result:** Container apiserver hangs. `trustd` denied writing to `/Users/pen-e2e-test-user/Library/Keychains`.

**Root cause:** XPC services inherit the client's sandbox profile. `trustd` (launched via XPC when the container system validates certificates) inherits our profile, but `-D` parameter bindings are NOT inherited. `(param "DENY_HOME")` resolves to empty string in the XPC service. `(subpath "")` matches all paths, so `(deny file-write* (subpath ""))` blocks all writes system-wide.

**Evidence:** `trustd` logs show `sandbox compile: using compatibility definitions for version 1 (latest version is 3)` — confirming it compiled our v1 profile. Followed by `home directory is inaccessible` and repeated `could not create path: /Users/pen-e2e-test-user/Library/Keychains/... (Operation not permitted)`.

## Attempt 2: Hardcoded paths, single profile

Eliminated `-D` params. Hardcoded the deny target:

```scheme
(version 1)
(allow default)
(deny file-write* (subpath "/Users"))
(allow file-write* (subpath "/Users/pen-e2e-test-user"))
```

SBPL uses last-match-wins evaluation, so the allow should override the deny for the test user's home.

**Result:** Still failing. `trustd` denied writing to `/Users/pen-e2e-test-user/Library/Keychains`. The allow rule either doesn't survive XPC inheritance or interacts unpredictably with `trustd`'s own system sandbox profile.

## Attempt 3: Three tiered profiles

Three profiles matched to script needs:

1. **`e2e-user-home-only.sb`** — `copy-container-data.sh`, `copy-pen-source.sh`:
   ```scheme
   (version 1)
   (allow default)
   (deny file-write*)
   (allow file-write* (subpath "/Users/pen-e2e-test-user"))
   ```

2. **`e2e-sudoers-only.sb`** — `add-test-sudoers.sh`, `remove-test-sudoers.sh`:
   ```scheme
   (version 1)
   (allow default)
   (deny file-write*)
   (allow file-write* (subpath "/etc/sudoers.d"))
   ```

3. **`e2e-ops.sb`** — `create-test-user.sh`, `delete-test-account.sh`:
   ```scheme
   (version 1)
   (allow default)
   (deny file-write* (subpath "/Users"))
   (allow file-write* (subpath "/Users/pen-e2e-test-user"))
   ```

**Result:** Two problems:

1. `trustd` still denied (same XPC inheritance issue as attempt 2)
2. `(deny file-write*)` blocks `/dev/null` — scripts can't redirect to `/dev/null`, breaking basic shell operations like `id "$target" &>/dev/null`. Would require allowlisting `/dev/`, `/tmp/`, `/private/var/folders/`, etc., eroding the deny-all intent.

## Why XPC inheritance is the fundamental blocker

macOS system services like `trustd` are per-user XPC daemons launched by `launchd`. When a sandboxed process triggers an XPC connection (directly or indirectly through system frameworks), the XPC service may inherit sandbox restrictions from the client. This is:

- **Undocumented** — Apple doesn't document the inheritance semantics
- **Unpredictable** — allow rules may not propagate, or may interact with the service's own profile
- **Unavoidable** — any script that creates users, copies files to Library dirs, or starts the container system will trigger XPC services

The only way to avoid this is to not sandbox scripts that might trigger XPC services, which defeats the purpose for the scripts that need the most protection.

## Decision

Abandon Seatbelt sandboxing for e2e test scripts. The existing mitigations (root:wheel ownership, guard functions, scoped sudoers, single-responsibility scripts) provide sufficient protection. See `doc/plans/hardening-privileged-test-scripts.md` for the full evaluation of hardening techniques.
