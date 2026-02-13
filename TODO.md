# TODO

## Container image

| # | Item | Notes | Security Concern? |
|---|------|-------|-------------------|
| 1 | Default lightweight Dockerfile | Should not depend on `docker/sandbox-templates` and should not bundle Claude | |
| 2 | Overridable Dockerfile for `pen build` | Default Dockerfile for `pen build`, but with overridable Dockerfile option defined in pen's config. Users should be able to extend the default image (e.g. `FROM` referencing the default image via a build arg) | |
| 3 | `pen build` docker context | Should take its docker context from inside `penctl/image` when building the default Dockerfile. Override Dockerfiles can use broader context from `pen build` execution directory | |
| 4 | tini as PID 1 | Use tini as PID 1 in Docker to reap zombies; start supervisord under it | |

## Networking

| # | Item | Notes | Security Concern? |
|---|------|-------|-------------------|
| 1 | Tighten pfctl wrapper | Perform bridge interface lookup and pf rule generation inside the wrapper, so sudoer access cannot be abused to apply arbitrary pf rules to any interface | Privilege escalation: sudoer wrapper can apply arbitrary pf rules to any interface |
| 2 | Simplify pf rules | Omit `from <ip>` directive entirely; rules should only use `on <interface>` and `to <ip> port <port>` directives, since each container has a dedicated bridge interface | Firewall bypass: `from <ip>` match could be defeated by IP spoofing or misconfiguration |
| 3 | Start HTTP proxy on available port | Use an available port above 8080 instead of hardcoding | |
| 4 | Remove UDP port 53 (DNS) from pf rules | HTTP/HTTPS traffic resolves DNS on the host via the proxy, so the container may not need direct DNS. Investigate whether removing it breaks anything (e.g. tools that resolve hostnames before connecting, or non-HTTP workflows). If not needed, removing it tightens the sandbox by closing a DNS tunneling exfiltration channel | Data exfiltration: open DNS port enables DNS tunnelling out of the sandbox |
| 5 | Evaluate unique subnet per container | Determine whether unique subnet per container is important, given each container already gets a dedicated bridge interface. If not required, remove custom auto-increment subnet logic and let the `container` tool assign subnets by default | |
| 6 | SSH config setup should append, not clobber | `pen start` SSH config setup should append the ProxyCommand directive instead of clobbering `~/.ssh/config` inside the container. Merge the `Host *` ProxyCommand block if file already exists | Config destruction: clobbering may silently remove security-relevant SSH settings |
| 7 | Investigate Apple Container DNS vs CloudFlare WARP conflict | Previously both tried to bind to port 53, blocking each other. If resolved, document what fixed it | |
| 8 | Open SSH from host to sandbox | Support connecting IDE GUI on host to IDE server running in the sandbox | |
| 9 | Fail `start.sh` if proxy cannot start | Detect proxy startup failure (e.g. port collision) and fail `start.sh` early instead of continuing with a broken proxy | |
| 10 | Avoid proxy log growing indefinitely | Drop old log lines to prevent unbounded growth of the proxy log file | Host DoS: agent can generate traffic to fill host disk |
| 11 | Improve blocked-request response from HTTP proxy | Return a more appropriate response body and status code when the HTTP proxy blocks a request | |
| 12 | Show TCP/UDP activity in `pen proxy logs` | Currently only shows HTTP proxy activity. Investigate tunnelling all traffic via HTTP proxy using HTTP CONNECT so TCP/UDP activity is also visible | |
| 13 | More appropriate default allowlists | Review and improve the default HTTP and network allowlists shipped with pen | |

## Configuration

| # | Item | Notes | Security Concern? |
|---|------|-------|-------------------|
| 1 | Pen config file (JSON) | Containing allowed HTTP and network allowlists, plus other config like Dockerfile override | |
| 2 | Configurable environment variables | Allow setting arbitrary env vars in the sandbox. Enables use cases like setting `SSL_CERT_FILE` to point to a custom certificate for corporate proxy TLS termination | |
| 3 | Configurable volume mounts | Always delete container on stop/restart but retain useful data (e.g. docker volumes) and mount in useful config (e.g. git config). Support both host-bound and non-host-bound volumes. Examples: exposing coding agent system-wide config, caching coding agent API keys / credentials | |
| 4 | Configure CPU and memory limits | Set CPU and memory limits for the container | |

## CLI

| # | Item | Notes | Security Concern? |
|---|------|-------|-------------------|
| 1 | Shell completion | `pen completion` prints shell commands for `.bashrc` or `.zshrc` to add `pen` shell completion | |
| 2 | Report container resource stats | Display CPU, memory, and other resource usage for the running sandbox | |
| 3 | `pen proxy logs`: hide successful traffic by default | Only show rejected traffic and errors by default; successful/allowed traffic should be hidden unless verbose mode is enabled | |
| 4 | `pen config apply` | Copy project-sited config (allowlists etc.) from `.pen/` in the project repo to the live config in `$HOME/.pen/sandboxes/<sandbox-id>/`. Warning: opens a potential security hole if an agent modifies the project-sited config and it is subsequently applied to `$HOME/.pen/...`. User should review config before applying. Useful for letting teams check in project-specific allowlists without letting the agent change the live config from inside the sandbox | |
| 5 | `pen config backup` | Pull live config from `$HOME/.pen/sandboxes/<sandbox-id>/` back into `.pen/` in the project repo, so it can be checked into version control | |
| 6 | Git-ignore only runtime artifacts in `.pen/` | `.pen/` now stores both checked-in config (allowlists) and runtime artifacts. Only git-ignore log and PID files, not the entire `.pen/` directory | Config tampering: fully git-ignored `.pen/` hides agent modifications to project-sited config |

## Documentation

| # | Item | Notes | Security Concern? |
|---|------|-------|-------------------|
| 1 | Recipes docs | Add a "recipes" section documenting common workflows, including how to inject AWS credentials for an AWS SSO profile | |
| 2 | Agent sandbox awareness files | Provide `CLAUDE.md` and `AGENTS.md` files in the directory hierarchy that inform coding agents (e.g. Claude, Codex) they are running in a sandboxed environment with network egress controls | |

## Testing

| # | Item | Notes | Security Concern? |
|---|------|-------|-------------------|
| 1 | End-to-end tests | Automated testing of pen scripts end to end. Use [nested virtualization](https://github.com/apple/container/blob/main/docs/how-to.md#expose-virtualization-capabilities-to-a-container) (`container run --virtualization`) to run tests inside an Apple Container, avoiding interference with the host machine's installed `pen`. Requires M3 or newer Apple silicon and a macOS container image (not Linux), since pen depends on macOS host tools (pf, Apple `container` CLI) | |
| 2 | Unit tests | Unit tests for individual functions and scripts | |

## Code quality

| # | Item | Notes | Security Concern? |
|---|------|-------|-------------------|
| 1 | Decompose `start.sh` | Split into separate concerns in separate scripts or functions | |
| 2 | Reduce duplication across scripts | Reduce duplication across `install.sh`, `uninstall.sh`, and other scripts | |
| 3 | Collapse `./penctl` into project root | Move contents of `penctl/` to the project root to flatten the directory structure | |
| 4 | Evaluate removing `request()` from egress proxy | Determine whether `request()` can be removed from `penctl/commands/lib/egress-proxy.py` | |
