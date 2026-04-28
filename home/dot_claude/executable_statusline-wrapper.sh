#!/bin/bash

input=$(cat)

git_info=$(echo "$input" | bash ~/.claude/statusline-command.sh)
context_pct=$(echo "$input" | ccstatusline)

printf '%s | %s' "$git_info" "$context_pct"
