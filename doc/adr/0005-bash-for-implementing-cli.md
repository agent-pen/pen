# 5. bash-for-implementing-cli

Date: 2026-02-12

## Status

Accepted

## Context

We need to implement a command-line interface for users to manage their agent sandbox. The CLI will delegate to other command-line tools, such as Apple's `container` CLI.

CLIs can be built using any programming language. Some, such as `nodejs`, require a language runtime to be installed on the host machine. This impacts portability and user experience. Other languages, such as `rust`, afford great runtime performance but require dedicated build and distribution steps in their development workflow. `bash` is supported on Linux and MacOS by default. Scripts can run without any additional compilation or packaging.    

## Decision

We will use `bash` to implement the CLI, due to its cross-platform portability and the fact that it does not require a compilation step.

## Consequences

What becomes easier or more difficult to do and any risks introduced by the change that will need to be mitigated.
