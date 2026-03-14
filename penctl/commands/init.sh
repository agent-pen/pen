#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

source "${PEN_HOME}/penctl/commands/lib/common.sh"

abort_if_already_initialized() {
  if [[ -d "$sandbox_config_dir" ]]; then
    echo "Already initialized: ${sandbox_config_dir}"
    exit 0
  fi
}

create_sandbox_config_dir() {
  mkdir "$sandbox_config_dir"
}

create_default_allowlists() {
  local defaults_dir="${PEN_HOME}/penctl/defaults"

  cp "${defaults_dir}/http-allowlist.txt" "${sandbox_config_dir}/http-allowlist.txt"
  cp "${defaults_dir}/network-allowlist.txt" "${sandbox_config_dir}/network-allowlist.txt"
}

create_project_pen_dir() {
  mkdir -p "${PEN_PROJECT}/.pen"

  cat > "${PEN_PROJECT}/.pen/.gitignore" << 'EOF'
proxy.pid
proxy.log
EOF
}

abort_if_already_initialized
create_sandbox_config_dir
create_default_allowlists
create_project_pen_dir
echo "Initialisation succeeded."
