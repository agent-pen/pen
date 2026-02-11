#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

source "${PEN_HOME}/penctl/commands/lib/common.sh"

pen_dir="${PEN_PROJECT}/.pen"

if [[ -d "$pen_dir" ]]; then
  echo "Already initialized: ${pen_dir}"
  exit 0
fi


mkdir -p "$pen_dir"

cat > "${pen_dir}/http-allowlist.txt" << 'ALLOWLIST'
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

cat > "${pen_dir}/network-allowlist.txt" << 'ALLOWLIST'
# IP-based egress rules for non-HTTP protocols (e.g. SSH for git).
# These bypass the HTTP proxy and go through pf directly (TCP and UDP).
# Format: ip:port (one per line, # comments supported)
ALLOWLIST

gitignore="${PEN_PROJECT}/.gitignore"
entries=(".pen/proxy.pid" ".pen/proxy.log")
for entry in "${entries[@]}"; do
  if [[ -f "$gitignore" ]] && grep -qF "$entry" "$gitignore"; then
    continue
  fi
  echo "$entry" >> "$gitignore"
done

echo "Initialisation succeeded."
