#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

bash "${PEN_HOME}/penctl/commands/stop.sh" 2>/dev/null || true
exec bash "${PEN_HOME}/penctl/commands/start.sh"
