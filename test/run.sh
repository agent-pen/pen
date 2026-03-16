#!/usr/bin/env bash
# Run bats tests. Must run as the test user inside their Mach context.
# Usage: run.sh [file.bats] [test-name-filter]

set -o nounset -o errexit -o pipefail

export PEN_REPO="$HOME/pen-source"

BATS_FILE="${1:-}"
BATS_FILTER="${2:-}"

BATS_ARGS=()
if [ -n "$BATS_FILTER" ]; then
    BATS_ARGS+=(-f "$BATS_FILTER")
fi

if [ -n "$BATS_FILE" ]; then
    exec bats ${BATS_ARGS[@]+"${BATS_ARGS[@]}"} "$PEN_REPO/test/suite/$BATS_FILE"
else
    exec bats ${BATS_ARGS[@]+"${BATS_ARGS[@]}"} "$PEN_REPO/test/suite/"
fi
