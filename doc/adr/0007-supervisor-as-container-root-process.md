# 7. supervisor-as-container-root-process

Date: 2026-02-12

## Status

Accepted

## Context

We need a way for the sandbox container to keep running indefinitely once started. Additionally, we need to start the docker daemon so `docker` is available by default.

## Decision

Use [supervisord](https://supervisord.org/) as PID 1 in the container. Configure it to start the docker daemon and block indefinitely. 

## Consequences

The approach is readily understood by others due to the widespread use of [supervisord](https://supervisord.org/).
