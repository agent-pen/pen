#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

bash "${PEN_HOME}/penctl/commands/start.sh"

source "${PEN_HOME}/penctl/commands/lib/common.sh"

container exec -it --workdir "$PEN_PROJECT" "$target" bash
