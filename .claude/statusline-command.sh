#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract fields from statusline JSON
used_percentage=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
model_name=$(echo "$input" | jq -r '.model.display_name // empty')

# Effort isn't exposed via statusline JSON — read from settings.json
effort=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)

# Build the status line with path
status=$(printf '\033[01;34m%s\033[00m' "$(pwd | sed "s|^$HOME|~|")")

# Add model and effort (dim/cyan)
if [ -n "$model_name" ]; then
    # "Opus 4.7 (1M context)" -> "Opus 4.7 1M"
    meta=$(echo "$model_name" | sed -E 's/ \(([0-9]+[KM]) context\)/ \1/')
    [ -n "$effort" ] && meta="$meta/$effort"
    status="$status $(printf '\033[36m[%s]\033[00m' "$meta")"
fi

# Add git branch if in a repo, prefixed with 🌳 if in a worktree
branch=$(git symbolic-ref --short HEAD 2>/dev/null)
if [ -n "$branch" ]; then
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [ -n "$git_dir" ] && [[ "$git_dir" == *"/worktrees/"* ]]; then
        branch="🌳$branch"
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
