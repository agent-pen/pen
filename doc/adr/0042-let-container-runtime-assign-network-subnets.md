# 42. Let container runtime assign network subnets

Date: 2026-03-16

## Status

Accepted

## Context

`start.sh` manually assigned subnets by parsing `container network ls` to find the highest existing subnet octet and incrementing it. This was a precaution against subnet collisions between sandboxes — the runtime was observed reusing the same CIDR for new networks while previous networks were still running.

However, CIDR reuse is harmless. Each sandbox gets a dedicated bridge interface (ADR 0012), and the subnet CIDR is only meaningful within that bridge's scope. Two bridges can both use the same CIDR without conflicting because packets stay on their respective bridge unless explicitly routed elsewhere — the same reason two home routers can both hand out `192.168.1.x` addresses. The collision concern was unfounded.

The manual auto-increment also introduced a race condition: two parallel `pen start` calls could read the same max subnet and both try to create a network with the same CIDR, causing one to fail. This blocked parallel test execution.

## Decision

Remove the manual subnet auto-increment. Create networks with `container network create` without `--subnet` and read the runtime-assigned subnet and gateway from `container network list --format json` (fields `.status.ipv4Subnet` and `.status.ipv4Gateway`).

## Consequences

- Parallel sandbox creation is safe — the runtime handles subnet allocation.
- The gateway IP is read from JSON rather than derived by string manipulation, which is more robust.
- Removes ~3 lines of fragile sed/grep/sort parsing.
