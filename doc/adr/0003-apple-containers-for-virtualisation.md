# 3. apple-containers-for-virtualisation

Date: 2026-02-11

## Status

Accepted

## Context

[ADR 2: Virtual Machines for sandboxing agents](./0002-virtual-machines-for-sandboxing-agents.md) determined that we will use VMs for sandboxing. Virtual machine technologies are typically heavyweight in nature. 

As a tool for developers, we want to provide a source-controllable, low-ceremony, fast solution for sandboxing.

Docker [sandboxes](https://docs.docker.com/ai/sandboxes/) are a new technology that offers a lightweight, developer-centric (and agent-first) VM solution. Docker sandbox creates a MicroVM around each docker container, with its [own dedicated OS kernel and docker daemon](https://docs.docker.com/ai/sandboxes/architecture/). It comes with built-in network egress controls for hostnames, IPs and ports. This technology is in its infancy, however. It does not support exposing ports to the host machine (e.g. for connecting an IDE GUI to the sandbox), uses file synching instead of volume mounting (adding high latency to IO-intensive operations like `npm install`), only allows one file tree to be synced into the sandbox, and provided no control over CPU and memory allocation. These issues will undoubtably be addresses in time. A more persistent issue, however, is that docker sandbox requires a [Docker Desktop](https://www.docker.com/products/docker-desktop/) licence, costing between $100 and $300 per year, depending on org size.

[Apple Containers](https://github.com/apple/container) is another recent technology that provides lightweight VMs that start in seconds. It is built on Apple's [Virtualization framework](https://developer.apple.com/documentation/virtualization) and uses OCI image definitions (i.e. a Dockerfile) to define the runtime environment. It comes free with recent editions of Mac OS and requires Tahoe for full compatibility. It has the edge over docker sandbox in terms of file IO speed because (one or multiple) file trees are mounted, rather than synced. As a more feature-rich solution than docker sandbox, Apple Containers support exposing ports to the host machine and even surfacing them via local DNS. On the other hand, unlike docker sandbox, there is no first-class support for network egress controls. It has also been noted that, currently, the DNS server started by Apple Containers [conflicts with any existing process listening on port 53](https://github.com/apple/container/issues/402), such as [Cloudflare WARP](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/warp/).

## Decision

We will use [Apple Containers](https://github.com/apple/container) (built on Apple's [Virtualization framework](https://developer.apple.com/documentation/virtualization)) to run virtual machines due to their cost (free), support for OCI images and relative maturity compared to [docker sandbox](https://docs.docker.com/ai/sandboxes/).

## Consequences

We will only support MacOS host environments initially. Support for other operating systems will only be possible through the addition of alternative virtualisation technologies.

We will need to implement a custom solution for network egress control.

We will need to workaround the port 53 conflict, e.g. by intercepting container DNS requests.
