#!/usr/bin/env bash
# One-time dev machine setup for working on pen.
# Usage: ./development.sh

set -o nounset -o errexit -o pipefail

PEN_HOME="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing base dependencies (Brewfile)..."
HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="${PEN_HOME}/Brewfile"

echo "Installing dev dependencies (Brewfile.dev)..."
HOMEBREW_NO_AUTO_UPDATE=1 brew bundle --file="${PEN_HOME}/Brewfile.dev"

echo "Dev setup complete."
