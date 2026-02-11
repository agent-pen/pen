# 12. restrict network egress using pf

Date: 2026-02-12

## Status

Accepted

## Context

The primary goal of a sandbox is to limit a coding agent's ability to execute damaging operations. Unrestricted network egress is a key vector for data exfiltration and executing malicious actions against remote targets.

Developers need the ability to tightly control network egress. All outbound traffic should be denied by default, with only approved hosts made accessible. 

Critically, network egress controls must not be configurable from within the sandbox. Otherwise, a coding agent could modify the rules.

## Decision

We will use MacOS' `pf` packet filtering firewall to block all outbound network requests by default. Only IPs and ports explicitly configured by the developer will be accessible. Additionally, we will configure a `pf` rule to permit egress of DNS requests on port 53.

`pf` is managed from outside the sandbox, on the host machine where a coding agent has no ability to take action. 

We will create a dedicated Apple container network per Apple container. This enables `pf` rules to bind to the network's bridge interface. In this way, the rules will only apply to a single container.

Additionally, a dedicated network per container removes the risk of egress from one container to another on the same network.

## Consequences

There will be a sub-second time interval after the sandbox starts but before the egress controls are in place. This is because determining the bridge interface requires inspecting the Apple container for its IP.

A configuration file will be required to allow users to curate the approved list of <ip>:<port> combinations. 
