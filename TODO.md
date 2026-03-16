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
| 6 | SSH config setup should append, not clobber | `pen start` SSH config setup should append the ProxyCommand directive instead of clobbering `~/.ssh/config` inside the container. Merge the `Host *` ProxyCommand block if file already exists | Config destruction: clobbering may silently remove security-relevant SSH settings |
| 7 | Investigate Apple Container DNS vs CloudFlare WARP conflict | Previously both tried to bind to port 53, blocking each other. If resolved, document what fixed it | |
| 8 | Open SSH from host to sandbox | Support connecting IDE GUI on host to IDE server running in the sandbox | |
| 9 | Fail `start.sh` if proxy cannot start | Detect proxy startup failure (e.g. port collision) and fail `start.sh` early instead of continuing with a broken proxy. The `nc -z` readiness poll has no timeout — hangs indefinitely if the proxy never starts | |
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
| 7 | Stop all pen instances before uninstall | `uninstall.sh` should stop all running pen sandboxes for the user before removing pen | |
| 8 | Auto-build on `pen start` if no image | `start.sh` currently fails with "Image not found" if no image exists. Instead, auto-run `pen build` with the default Dockerfile so `pen exec` / `pen shell` work without a separate build step | |
| 9 | Fail `pen build` and `pen start` if `pen init` not run | Guard against running pen in the wrong directory. Check that `pen init` has been run for the current directory before allowing `pen build` or `pen start` to proceed | |

## Documentation

| # | Item | Notes | Security Concern? |
|---|------|-------|-------------------|
| 1 | Recipes docs | Add a "recipes" section documenting common workflows, including how to inject AWS credentials for an AWS SSO profile | |
| 2 | Agent sandbox awareness files | Provide `CLAUDE.md` and `AGENTS.md` files in the directory hierarchy that inform coding agents (e.g. Claude, Codex) they are running in a sandboxed environment with network egress controls | |

## Testing

| # | Item | Notes | Security Concern? |
|---|------|-------|-------------------|
| 1 | Unit tests | Unit tests for individual functions and scripts | |
| 2 | Run e2e tests in CI | Self-hosted macOS runner (Apple Silicon, Tahoe 26.x+). See `doc/testing-strategy.md` | |
| 3 | Verify `--enable-kernel-install` downloads without prompting in CI | CI won't have a pre-copied kernel, so `ensure_container_system` will trigger the ~450MB download. Verify this completes non-interactively | |
| 5 | Atomic sudoers write in `add-test-sudoers.sh` | Write sudoers to a temp file, validate with `visudo -cf`, then `mv` into place. Currently writes directly then validates, leaving a malformed file on disk if validation fails | |
| 8 | Force-clean sandbox resources in test teardown | Test teardown (`delete-test-user.sh`) hangs if a sandbox is still running when the test user is deleted. Teardown should force-stop containers and clean up pf/proxy/network before deleting the account |
| 9 | Use `cp -RP` in `copy-pen-source.sh` | `cp -R` follows symlinks. A symlink in the working tree pointing to a sensitive file would be copied as a regular file readable by the test user. `cp -RP` preserves symlinks as symlinks | |
| 10 | Investigate `chmod u-w` on root-owned privileged scripts | Claude Code's Edit tool bypasses filesystem permissions to write to `root:wheel` files. Test whether removing owner write (`chmod u-w`) blocks this. If so, `develop.sh` should set `r-xr-xr-x` on privileged scripts instead of `rwxr-xr-x` | Agent can modify privileged scripts despite root ownership |
| 11 | Faster edit-test loop for interactive debugging | Currently must re-run `setup.sh` to copy source after edits, which recreates the test user. Not ergonomic when using `shell-test-user.sh` for interactive iteration | |
| 12 | Sanitize pfctl anchor suffix in `pfctl-wrapper.sh` | Anchor name is only prefix-checked. Add a character class validation (e.g. `[a-zA-Z0-9._-]`) to prevent unexpected characters reaching `pfctl -a` | Privilege escalation: unconstrained suffix passed to root-executed pfctl |
| 13 | Avoid macOS GUI authorization prompt when test source files change | Changing test source files triggers a macOS dialog asking the user to authorize the terminal app. Investigate granting Full Disk Access or Developer Tool access to the terminal to suppress this | |
| 15 | Parallel test execution with bats `--jobs` | Tests already use per-test isolation via `ensure_test_isolation`. Enable `--jobs N` for parallel file/method execution. Needs: separate project directory per test method (not just per file), and install/uninstall tests excluded from parallel runs or rearchitected | |
| 16 | Retain test user across development runs | Skip test user creation/deletion during `./test.sh` when the test user already exists, saving ~15s. Pre-commit hook and CI must always do a full recreation for isolation. Needs: a mode flag or separate entry point, and a reset mechanism to clear stale sandbox state without recreating the account | |

## Dependencies

| # | Item | Notes | Security Concern? |
|---|------|-------|-------------------|
| 1 | Investigate adding Apple `container` CLI to Brewfile | Compatibility with existing direct installs is unknown — may conflict | |

## Bugs

| # | Item | Notes | Security Concern? |
|---|------|-------|-------------------|
| 1 | Support directories with dot (`.`) in name | `common.sh` uses `basename "$PEN_PROJECT"` in the container name, which can include dots. Dots are invalid in container/image references — e.g. directory `tmp.OlZ2tz4L7L` produces `pen-user-502-project-tmp.OlZ2tz4L7L-61c362`, causing `Error: invalid reference`. Sanitize or replace dots in the basename | |

## Code quality

| # | Item | Notes | Security Concern? |
|---|------|-------|-------------------|
| 1 | Decompose `start.sh` | Split into separate concerns in separate scripts or functions | |
| 2 | Migrate `uninstall.sh` into `install.sh --undo` | Consolidate install and uninstall into a single script, matching the `develop.sh --undo` pattern | |
| 3 | Reduce duplication across scripts | Reduce duplication across `install.sh`, `uninstall.sh`, and other scripts | |
| 3 | Collapse `./penctl` into project root | Move contents of `penctl/` to the project root to flatten the directory structure | |
| 4 | Evaluate removing `request()` from egress proxy | Determine whether `request()` can be removed from `penctl/commands/lib/egress-proxy.py` | |
| 5 | Atomic sudoers write in `install.sh` | Same pattern as `add-test-sudoers.sh` — write to temp file, validate with `visudo -cf`, then `mv` into place | |
| 6 | Code linting and formatting | Add shellcheck and shfmt (or similar) to enforce consistent style and catch bugs statically | |
| 7 | Code complexity thresholds | Enforce function length / cyclomatic complexity limits to keep scripts decomposed | |
| 8 | Automatic code review agent workflow step | Add an agent-driven code review step to the development workflow. Consider adopting an opinionated workflow like [nwave.ai](https://nwave.ai/) | |
