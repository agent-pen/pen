# 35. Flush pf anchors during test account deletion

Date: 2026-03-09

## Status

Accepted

## Context

When deleting the test user account, pen's pf anchors for that user remain loaded. If a process is still running and relying on pf rules (e.g. for egress filtering), flushing anchors while it's active could leave it in an unexpected state. The anchors also need to be discovered correctly — they are nested under `com.apple/` and `pfctl -s Anchors` only lists top-level anchors.

## Decision

Flush all pf anchors belonging to the test user during account deletion. Kill all user processes first to ensure nothing relies on the pf rules at the time of flushing. Query nested anchors with `pfctl -a com.apple -s Anchors` and tolerate leading whitespace in the output.

## Consequences

Test cleanup fully removes the test user's pf state. Ordering matters: processes must be killed before anchors are flushed to avoid a window where a running process has no firewall rules. The empty anchor shells persist until reboot (pf provides no API to remove them) but are harmless.
