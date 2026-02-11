# 2. virtual-machines-for-sandboxing-agents

Date: 2026-02-11

## Status

Accepted

Extended [3. apple-containers-for-virtualisation](0003-apple-containers-for-virtualisation.md)

## Context

### Coding with agents is inherently insecure

We cannot trust coding agents to self-block all attempts at damaging operations (e.g. exfiltrating sensitive data, deleting production infrastructure). Additionally, humans cannot be expected to anticipate every possible attack vector.

Coding agents provide mechanisms for restricting file system and network access, and tool execution, but coverage is patchy in coverage and can be circumvented easily.

### Sandboxes

"Sandboxing" a coding agent in a isolated host environment lets us limit its access to sensitive local data (e.g. credentials), control its ability to communicate externally (e.g. with malicious third-party servers) and restrict its exposure to untrusted content (e.g. GitHub issues containing malicious prompts). This is the [Lethal Trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/) of capabilities that, if available to an agent, means "an attacker can easily trick it into accessing your private data and sending it to that attacker" (Simon Willison).

### Containers as sandboxes

A typical sandboxing approach is to run the coding agent in a docker container, with a project source tree directory mounted into the container. The container can be denied root access and have privileged capabilities removed. Additionally, the containers networking can be configured to restrict outbound requests to approved hosts and IPs.

### Containers aren't secure enough

Unfortunately, container restrictions can be circumvented with relative ease, providing agents with access to the host environment. For example, if a project requires access to the docker daemon (e.g. to run `docker compose`), it is possible for an agent to perform operations against the host environment via an arbitrary docker container.


### Virtual machines are more secure

VMs do not share a kernel or docker daemon with the host machine. This significantly reduces the pathways by which a coding agent can gain access to the host machine.

## Decision

We will rely on virtual machines to implement agent sandboxes due to their superior ability to restrict access to host environments.

## Consequences

Our implementation will be less portable than a docker-based solution. It will need to leverage OS-specific technologies. Supporting multiple operating systems will require some duplication of effort. We are more likely to focus on a single OS to start with.
