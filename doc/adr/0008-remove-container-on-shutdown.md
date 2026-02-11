# 8. remove-container-on-shutdown

Date: 2026-02-12

## Status

Accepted

## Context

Sandboxes are intended to be easily shared and recreated by all members of a project team. This is only possible if users think of them as highly-ephemeral, with all important data stored outside the container. To encourage developers to treat the sandbox this way, instances should not behave like long-lived artifacts on developer machines. 

## Decision

Containers are automatically removed when stopped. 

## Consequences

Ultimately, we will need to implement support for mounting multiple volumes, e.g. to persist docker image cache between sandboxe recreation.  
