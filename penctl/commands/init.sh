#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

source "${PEN_HOME}/penctl/commands/lib/common.sh"

if [[ -d "$sandbox_config_dir" ]]; then
  echo "Already initialized: ${sandbox_config_dir}"
  exit 0
fi

mkdir -p "$sandbox_config_dir"

cat > "${sandbox_config_dir}/http-allowlist.txt" << 'ALLOWLIST'
# HTTP(S) proxy allowlist: host:port (one per line, # comments supported)
# Enforced by the pen egress proxy via hostname matching.

# Package registries
registry.npmjs.org:443
registry.yarnpkg.com:443

# Docker
auth.docker.io:443
registry-1.docker.io:443
production.cloudflare.docker.com:443

# System
download.docker.com:443
ports.ubuntu.com:443
ports.ubuntu.com:80
ALLOWLIST

cat > "${sandbox_config_dir}/network-allowlist.txt" << 'ALLOWLIST'
# IP-based egress rules for non-HTTP protocols (e.g. SSH for git).
# These bypass the HTTP proxy and go through pf directly (TCP and UDP).
# Format: ip:port (one per line, # comments supported)
ALLOWLIST

mkdir -p "${PEN_PROJECT}/.pen"

printf '\n/.pen/\n' >> "${PEN_PROJECT}/.gitignore"

echo "Initialisation succeeded."
