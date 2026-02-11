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
./install.sh
```

This symlinks `pen` into `/usr/local/bin` and configures passwordless sudo for firewall management. You will be prompted for your password once.

## Removal

```bash
./uninstall.sh
```

## Usage

### Initialize a project

From your project directory:

```bash
pen init
```

This creates a `.pen/` directory containing two allowlist config files:

- `http-allowlist.txt` — hostname:port pairs for HTTP/HTTPS traffic (e.g. `registry.npmjs.org:443`)
- `network-allowlist.txt` — ip:port pairs for non-HTTP protocols (e.g. raw TCP/SSH)

Edit these files to control what the sandbox can access. Both are default-deny: only listed entries are allowed through.

### Build the container image

```bash
pen build
```

Uses the default Dockerfile. To customize, place a `Dockerfile` in `.pen/` and it will be used instead.

### Start the sandbox

```bash
pen start
```

This creates an isolated VM with network restrictions and drops you into an interactive shell. Your project directory is mounted at the same path inside the sandbox.

### Stop the sandbox

```bash
pen stop
```

Tears down the VM, proxy, and firewall rules. The sandbox is ephemeral: all data inside it is lost. Only files in the mounted project directory persist.

### Other commands

```bash
pen restart           # Stop and start
pen status            # Check if the sandbox is running
pen shell             # Open a shell in a running sandbox
pen exec <cmd>        # Run a command in the sandbox
pen proxy logs        # Tail the HTTP proxy log
```

### SSH / git

SSH is automatically configured inside the sandbox to tunnel through the HTTP proxy. To allow git operations over SSH, add the git host to `http-allowlist.txt`:

```
github.com:22
```

No additional configuration is needed.
