# 33. Include user ID in container name for user-scoped resource identification

Date: 2026-03-09

## Status

Accepted

## Context

Pen derives container, network, image, and pf anchor names from a single `container_name` computed in `common.sh`. The previous format was `pen-<project basename>-<path hash>`, e.g. `pen-myproject-a1b2c3`.

This naming scheme made it impossible to identify which system resources (containers, networks, pf anchors) belonged to a specific user. This became a concrete problem during e2e test teardown: when cleaning up the test user's pf anchors, there was no way to enumerate just that user's anchors without either hardcoding the project path or flushing all pen anchors (risking interference with other users).

## Decision

Change the container name format to `pen-user-<UID>-project-<project basename>-<path hash>`.

All derived names (container, network, pf anchor, sandbox config directory) inherit this prefix automatically since they are all based on `container_name`.

The `pfctl-wrapper.sh` anchor prefix check (`com.apple/pen-`) remains valid for the new format and requires no change.

## Consequences

- User-scoped resource enumeration becomes possible. For example, test teardown can flush all pf anchors matching `com.apple/pen-user-<UID>-project-` for a specific user without affecting other users.
- Existing containers, networks, and images using the old naming convention become orphaned. Users must manually clean up old resources after upgrading.
- The container name is longer but remains within platform limits.
