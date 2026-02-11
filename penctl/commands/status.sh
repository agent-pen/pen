#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

source "${PEN_HOME}/penctl/commands/lib/common.sh"

if pen_is_running; then
  echo "Pen running"
else
  echo "Pen not running"
  exit 1
fi
