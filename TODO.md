# TODO

## Container image

| # | Item | Notes |
|---|------|-------|
| 1 | Default lightweight Dockerfile | Should not depend on `docker/sandbox-templates` and should not bundle Claude |
| 2 | Overridable Dockerfile for `pen build` | Default Dockerfile for `pen build`, but with overridable Dockerfile option defined in pen's config. Users should be able to extend the default image (e.g. `FROM` referencing the default image via a build arg) |
| 3 | `pen build` docker context | Should take its docker context from inside `penctl/image` when building the default Dockerfile. Override Dockerfiles can use broader context from `pen build` execution directory |
| 4 | tini as PID 1 | Use tini as PID 1 in Docker to reap zombies; start supervisord under it |

## Networking

| # | Item | Notes |
|---|------|-------|
| 1 | Tighten pfctl wrapper | Perform bridge interface lookup and pf rule generation inside the wrapper, so sudoer access cannot be abused to apply arbitrary pf rules to any interface |
| 2 | Simplify pf rules | Omit `from <ip>` directive entirely; rules should only use `on <interface>` and `to <ip> port <port>` directives, since each container has a dedicated bridge interface |
| 3 | Start HTTP proxy on available port | Use an available port above 8080 instead of hardcoding |
| 4 | Remove UDP port 53 (DNS) from pf rules | HTTP/HTTPS traffic resolves DNS on the host via the proxy, so the container may not need direct DNS. Investigate whether removing it breaks anything (e.g. tools that resolve hostnames before connecting, or non-HTTP workflows). If not needed, removing it tightens the sandbox by closing a DNS tunneling exfiltration channel |
| 5 | Evaluate unique subnet per container | Determine whether unique subnet per container is important, given each container already gets a dedicated bridge interface. If not required, remove custom auto-increment subnet logic and let the `container` tool assign subnets by default |
| 6 | SSH config setup should append, not clobber | `pen start` SSH config setup should append the ProxyCommand directive instead of clobbering `~/.ssh/config` inside the container. Merge the `Host *` ProxyCommand block if file already exists |
| 7 | Investigate Apple Container DNS vs CloudFlare WARP conflict | Previously both tried to bind to port 53, blocking each other. If resolved, document what fixed it |
| 8 | Open SSH from host to sandbox | Support connecting IDE GUI on host to IDE server running in the sandbox |

## Configuration

| # | Item | Notes |
|---|------|-------|
| 1 | Pen config file (JSON) | Containing allowed HTTP and network allowlists, plus other config like Dockerfile override |
| 3 | Configurable volume mounts | Always delete container on stop/restart but retain useful data (e.g. docker volumes) and mount in useful config (e.g. git config) |
| 4 | Configure CPU and memory limits | Set CPU and memory limits for the container |

## CLI

| # | Item | Notes |
|---|------|-------|
| 1 | Shell completion | `pen completion` prints shell commands for `.bashrc` or `.zshrc` to add `pen` shell completion |
| 2 | Report container resource stats | Display CPU, memory, and other resource usage for the running sandbox |

## Testing

| # | Item | Notes |
|---|------|-------|
| 1 | End-to-end tests | Automated testing of pen scripts end to end. Use [nested virtualization](https://github.com/apple/container/blob/main/docs/how-to.md#expose-virtualization-capabilities-to-a-container) (`container run --virtualization`) to run tests inside an Apple Container, avoiding interference with the host machine's installed `pen`. Requires M3 or newer Apple silicon and a macOS container image (not Linux), since pen depends on macOS host tools (pf, Apple `container` CLI) |
| 2 | Unit tests | Unit tests for individual functions and scripts |

## Code quality

| # | Item | Notes |
|---|------|-------|
| 1 | Decompose `start.sh` | Split into separate concerns in separate scripts or functions |
| 2 | Reduce duplication across scripts | Reduce duplication across `install.sh`, `uninstall.sh`, and other scripts |
| 3 | Collapse `./penctl` into project root | Move contents of `penctl/` to the project root to flatten the directory structure |
| 4 | Evaluate removing `request()` from egress proxy | Determine whether `request()` can be removed from `penctl/commands/lib/egress-proxy.py` |
