#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

source "${PEN_HOME}/penctl/commands/lib/common.sh"

if [[ -f "${PEN_PROJECT}/.pen/Dockerfile" ]]; then
  dockerfile="${PEN_PROJECT}/.pen/Dockerfile"
  context="$PEN_PROJECT"
else
  dockerfile="${PEN_HOME}/penctl/image/Dockerfile"
  context="${PEN_HOME}/penctl/image"
fi

container build -t "${container_name}" --file "$dockerfile" "$context"
