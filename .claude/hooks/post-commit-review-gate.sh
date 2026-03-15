#!/usr/bin/env bash

set -o nounset -o errexit -o pipefail

input=$(cat)

# Only act on Bash tool uses
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""')
if [[ "$tool_name" != "Bash" ]]; then
  exit 0
fi

# Only act on git commit commands (tolerate flags between git and commit)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
if ! printf '%s' "$command" | grep -qE '^git(\s+(-[a-zA-Z][\w-]*(\s+\S+)?)\s*)?\s+commit\b'; then
  exit 0
fi

# Skip review if the commit message contains the review marker
commit_msg=$(git log -1 --format=%B)
if printf '%s' "$commit_msg" | grep -qF '[automated subagent code review]'; then
  exit 0
fi

echo "Code committed. Run the code-reviewer subagent to review your changes before continuing." >&2
exit 2
