# 4. command-line-as-interface

Date: 2026-02-12

## Status

Accepted

## Context

Users will require an interface for managing the sandbox.

## Decision

We will use a command-line interface (as opposed to a rich desktop GUI, IDE plugin, webpage, voice or IoT interface) because it is the quickest to implement. It also fits a typical agentic coding workflow, where users interact via an agent CLI.

## Consequences

We can rapidly implement features as we explore the solution space. Future alternate interfaces can delegate to the CLI until it becomes a performance issue.
