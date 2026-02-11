# 6. claude-docker-sandbox-as-container-base-image

Date: 2026-02-12

## Status

Accepted

## Context

We want to provide users with a valuable default experience. The default sandbox should provide an environment likely to be useful to most users.

[Apple Containers](https://github.com/apple/container) use OCI images, so we must define a `Dockerfile` to build the container from. This needs to inherit from a base image. If we select a base image with sensible defaults, we can avoid configuring them ourselves.

## Decision

We will use the `docker/sandbox-templates:claude-code` docker image since it provides an ubuntu environment, a non-root sudo user, a mechanism for progressively customisaing bash session env vars, docker support, basic command line tools for development, `node`, `python`, and `go` support, and Claude Code pre-installed.

## Consequences

We will need to override the base image command so Claude Code does not automatically start.

We will likely need to move off the base image if we conclude it is too bloated with optional software (e.g. `node`, `python`, and `go` support and Claude Code).