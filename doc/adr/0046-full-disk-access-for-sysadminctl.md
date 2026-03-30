# 46. Full Disk Access for sysadminctl

Date: 2026-03-30

## Status

Accepted

## Context

`sysadminctl` (used to create and delete the e2e test user) triggers a macOS GUI dialog: "iTerm would like to administer your computer." This blocks automated test runs.

The dialog is a TCC (Transparency, Consent, and Control) check for `kTCCServiceSystemPolicySysAdminFiles`. When `sysadminctl` modifies a directory services record, `sandboxd` traces the process ancestry to find the responsible GUI app (e.g. iTerm), then checks whether that app has been granted the system admin files TCC permission. Without it, macOS prompts the user.

This is separate from Authorization Services (`authd`), which checks rights like `system.services.directory.configure`. Those checks pass automatically for root via the `is-root` rule (`k-of-n: 1`). The TCC check happens later, during the actual DS record modification.

## Decision

Require the terminal app to have Full Disk Access (`kTCCServiceSystemPolicyAllFiles`), which is a superset of `kTCCServiceSystemPolicySysAdminFiles`. This is a one-time manual step:

**System Settings > Privacy & Security > Full Disk Access > add terminal app**

`develop.sh` prints a reminder after setup. Both `create-test-user.sh` and `delete-test-account.sh` run `sysadminctl` directly — no wrappers or workarounds needed.

## Alternatives considered

**Launchd oneshot helper.** Running `sysadminctl` via a temporary LaunchDaemon (`launchd → wrapper → sysadminctl`) breaks the process ancestry so TCC has no GUI app to prompt about. This works for user creation but not deletion: `sysadminctl -deleteUser` via launchd reports success ("Deleting record") but the DS record is never committed. Investigation showed that `sandboxd`'s TCC check for `kTCCServiceSystemPolicySysAdminFiles` silently fails when there is no GUI app in the ancestry — the operation is acknowledged by `sysadminctl` but blocked at the file level by `sandboxd`. Rejected because it only solves half the problem.

**Modify the authdb authorization rights.** Temporarily setting `system.services.directory.configure`, `system.preferences`, and `system.preferences.accounts` to `allow` bypasses the Authorization Services checks. However, these are not the source of the GUI dialog — TCC is. The dialog still appeared after all three rights were set to `allow`. Rejected as it addresses the wrong layer.

**Direct dslocal plist manipulation.** User records live in `/var/db/dslocal/nodes/Default/users/`. Removing the plist directly would bypass `sysadminctl`. Rejected because `/var/db/dslocal/` is SIP-protected — even root cannot modify files there.

**`dscl . -delete` via launchd.** Also fails with `-14120 (eDSPermissionError)` — the same TCC restriction applies to the Directory Services API.

## Consequences

- One-time manual setup per terminal app, documented in `develop.sh`.
- No wrapper scripts, temporary LaunchDaemons, or authdb manipulation needed.
- Both create and delete use direct `sysadminctl` calls.
- The Full Disk Access grant persists across script changes, reboots, and terminal app updates (until the app's code signature changes, e.g. a major version update).
