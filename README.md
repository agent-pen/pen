# pen

Sandbox coding agents in Apple Container VMs with network egress control.

pen runs agents in isolated virtual machines with their own kernel, limiting access to host files and system resources. Network egress is controlled by a pf firewall (IP-based) and an HTTP proxy (hostname-based), both managed from the host where the agent cannot modify them.

## Prerequisites

- macOS Tahoe (26.x) or later
- [Apple Containers](https://github.com/apple/container)

```bash
brew install jq
brew install --cask mitmproxy
```

## Installation

```bash
git clone https://github.com/agent-pen/pen.git
cd pen
sudo ./install.sh
```

This symlinks `pen` into `~/.local/bin` and configures passwordless sudo for firewall management. Ensure `~/.local/bin` is on your PATH.

## Removal

```bash
sudo ./uninstall.sh
```

## Usage

### Initialize a project

From your project directory:

```bash
pen init
```

This creates egress allowlist config files in `~/.pen/sandboxes/<sandbox-id>/`:

- `http-allowlist.txt` — hostname:port pairs for HTTP/HTTPS traffic (e.g. `registry.npmjs.org:443`)
- `network-allowlist.txt` — ip:port pairs for non-HTTP protocols (e.g. raw TCP/SSH)

These files are stored outside the project directory so they cannot be modified from inside the sandbox. Edit them on the host to control what the sandbox can access. Both are default-deny: only listed entries are allowed through.

### Build the container image

```bash
pen build
```

Uses the default Dockerfile. To customize, place a `Dockerfile` in `.pen/` and it will be used instead.

### Open a shell in the sandbox

```bash
pen shell
```

This starts the sandbox (if not already running) and drops you into an interactive shell. Your project directory is mounted at the same path inside the sandbox.

### Stop the sandbox

```bash
pen stop
```

Tears down the VM, proxy, and firewall rules. The sandbox is ephemeral: all data inside it is lost. Only files in the mounted project directory persist.

### Other commands

```bash
pen start             # Start the sandbox without opening a shell
pen restart           # Stop and start
pen status            # Check if the sandbox is running
pen exec <cmd>        # Run a command (starts sandbox if needed)
pen proxy logs        # Tail the HTTP proxy log
```

### SSH / git

SSH is automatically configured inside the sandbox to tunnel through the HTTP proxy. To allow git operations over SSH, add the git host to `~/.pen/sandboxes/<sandbox-id>/http-allowlist.txt`:

```
github.com:22
```

No additional configuration is needed.

## Development

One-time setup:

```bash
sudo ./develop.sh
```

This installs dev dependencies, configures passwordless sudo for the test runner, and sets up git hooks. To remove: `sudo ./develop.sh --undo`.

Run end-to-end tests:

```bash
./test.sh
```

Tests also run automatically via the git pre-commit hook.

Debug interactively as the test user:

```bash
./test-user-shell.sh
```
