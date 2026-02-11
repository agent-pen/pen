# 10. sandbox per directory

Date: 2026-02-12

## Status

Accepted

## Context

Sandbox configuration will vary per code project. For example, different projects will require different OS packages to be installed in the sandbox environment.

Providing multiple sandboxes for a single directory would involve a more complicated user experience and require a sophisticated management features. 

## Decision

There will be a one-to-one relationship between a directory on a host machine and a `pen` sandbox.

## Consequences

Each Apple container artifact (e.g. a container instance or container image) will need its identifier to be derived from the directory it is associated with. 
