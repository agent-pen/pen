#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

source "${PEN_HOME}/penctl/commands/lib/common.sh"

ensure_container_system

pen_teardown
echo "Pen stopped."
