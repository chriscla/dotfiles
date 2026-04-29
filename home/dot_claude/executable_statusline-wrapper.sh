#!/bin/bash

input=$(cat)

git_info=$(echo "$input" | bash ~/.claude/statusline-command.sh)
context_pct=$(echo "$input" | ccstatusline)
model=$(echo "$input" | jq -r '.model.display_name // empty' 2>/dev/null)

if [ -n "$model" ]; then
  printf '%s | %s | \033[01;35m%s\033[00m' "$git_info" "$context_pct" "$model"
else
  printf '%s | %s' "$git_info" "$context_pct"
fi
