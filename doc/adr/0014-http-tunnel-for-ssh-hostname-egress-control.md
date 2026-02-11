# 14. http-tunnel-for-ssh-hostname-egress-control

Date: 2026-02-12

## Status

Accepted

## Context

SSH operations, e.g. to pull commits from a git repository, typically target a DNS hostname rather than a static IP.

By default, any hostname provided to the SSH client will be resolved to an IP before the connection is made. This means the IP address must be known ahead of time and added to the the list of allowed IPs, which drives `pf` firewall egress rules.

[ADR 14 mitmdump for DNS-based egress control](0013-mitmdump-for-dns-based-egress-control.md) established an approach for DNS-based egress control of HTTP requests via the `mitmdump` HTTP proxy. HTTP clients take note of sandbox environment variables and target their requests at the HTTP proxy. SSH clients will ignore these environment variables, however. 

## Decision

When starting a sandbox, we will set the SSH configuration to tunnel SSH connections over HTTP, via the mitmdump HTTP proxy. 

## Consequences

Users will need to take care not to remove the tunnel configuration when editing the sandbox SSH config.