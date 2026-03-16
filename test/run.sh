#!/usr/bin/env bash
# Run bats tests. Must run as the test user inside their Mach context.
# Usage: run.sh [file.bats] [test-name-filter]

set -o nounset -o errexit -o pipefail

export PEN_REPO="$HOME/pen-source"

BATS_FILE="${1:-}"
BATS_FILTER="${2:-}"

SUITE_DIR="$PEN_REPO/test/suite"

if [ -n "$BATS_FILE" ]; then
    BATS_ARGS=()
    if [ -n "$BATS_FILTER" ]; then
        BATS_ARGS+=(-f "$BATS_FILTER")
    fi
    exec bats ${BATS_ARGS[@]+"${BATS_ARGS[@]}"} "$SUITE_DIR/$BATS_FILE"
fi

# Run parallelisable tests (01–98).
parallel_files=("$SUITE_DIR"/[0-8]*.bats "$SUITE_DIR"/9[0-8]*.bats)
bats "${parallel_files[@]}"

# Run uninstall tests serially — must run after all others.
bats "$SUITE_DIR/99_uninstall.bats"
