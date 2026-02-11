# 13. mitmdump for DNS-based egress control

Date: 2026-02-12

## Status

Accepted

## Context

[ADR 12: Restrict network egress using pf](doc/adr/0012-restrict-network-egress-using-pf.md) introduced outbound network access controls based on IP addresses and ports.

Typically, DNS does not resolve hostnames to the same IPs on every request. This can be due to round-robin IP resolution or the non-static nature of network infrastructure.

Developers therefore need the ability to control egress based on hostnames.

As with IP-based egress controls, it is critical that DNS-based egress controls cannot be modified from inside the sandbox.

## Decision

We will use `mitmdump`, a lightweight command line HTTP proxy, for DNS-based sandbox egress control. It will run on the host machine, beyond the reach of a sandboxed coding agent.

We will configure a `pf` rule to allow egress from the Apple container network's bridge interface, so long as it targets the network's gateway IP and the http proxy's port.

`mitmdump` will listen for traffic targeting the container network's gateway IP and the http proxy's port. We will pass it a custom python script that blocks all outbound requests except for those to explcitly-approved hostnames. The script will not attempt to inspect request paths or headers, since this would require TLS termination and configuring custom certificates. Egress control will be based strictly upon hostnames.

Lastly, we will use sandbox environment variables to configure the HTTP proxy IP address and port. These will not affect sandbox-local traffic since the container image already sets the `NO_PROXY` env var to exclude local IPs from proxying.

## Consequences

We will need to provide a configuration file to enable developers to list approved hostnames.

DNS-based egress control will only be available for HTTP traffic. Raw TCP traffic (e.g. SSH or database connections) will require explicit <ip>:<port> rules in `pf` or the initiating application (e.g. ssh client) will need to configure tunelling via the `mitmdump` proxy, where hostname resolution can occur.