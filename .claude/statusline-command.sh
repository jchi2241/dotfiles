#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract context usage percentage
used_percentage=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Build the status line with path
status=$(printf '\033[01;34m%s\033[00m' "$(pwd | sed "s|^$HOME|~|")")

# Add git branch if in a repo, prefixed with wt: if in a worktree
branch=$(git symbolic-ref --short HEAD 2>/dev/null)
if [ -n "$branch" ]; then
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [ -n "$git_dir" ] && [[ "$git_dir" == *"/worktrees/"* ]]; then
        branch="worktree:$branch"
    fi
    status="$status $(printf '\033[01;32m(%s)\033[00m' "$branch")"
fi

# Add context usage progress bar if available
if [ -n "$used_percentage" ]; then
    PCT=$(echo "$used_percentage" | cut -d. -f1)
    BAR_WIDTH=10
    FILLED=$((PCT * BAR_WIDTH / 100))
    EMPTY=$((BAR_WIDTH - FILLED))
    BAR=""
    for ((i=0; i<FILLED; i++)); do BAR+="█"; done
    for ((i=0; i<EMPTY; i++)); do BAR+="░"; done
    # Color: green <40%, yellow 40-79%, red 80%+
    if [ "$PCT" -ge 80 ]; then BAR_COLOR='\033[31m'
    elif [ "$PCT" -ge 40 ]; then BAR_COLOR='\033[33m'
    else BAR_COLOR='\033[32m'; fi
    status="$status ${BAR_COLOR}${BAR}\033[00m ${PCT}%"
fi

printf '%b\n' "$status"
