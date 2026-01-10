#!/bin/bash
# Claude Code pre-tool-use hook to load direnv

# Read the tool input from stdin
input=$(cat)

# Extract the command from the JSON input
command=$(echo "$input" | jq -r '.command // empty')

# If no command, just pass through
if [ -z "$command" ]; then
    echo "$input"
    exit 0
fi

# Check if direnv is needed by looking for .envrc in the directory tree
cwd=$(echo "$input" | jq -r '.cwd // empty')
cwd="${cwd:-$PWD}"

needs_direnv=false
check_dir="$cwd"
while [ "$check_dir" != "/" ]; do
    if [ -f "$check_dir/.envrc" ]; then
        needs_direnv=true
        break
    fi
    check_dir=$(dirname "$check_dir")
done

# Skip direnv if no .envrc found
if [ "$needs_direnv" = false ]; then
    echo "$input"
    exit 0
fi

# Prepend direnv initialization to the command
# This ensures direnv is hooked and will export vars based on .envrc in the working directory
modified_command="eval \"\$(direnv hook bash)\" 2>/dev/null; eval \"\$(direnv export bash 2>/dev/null)\"; $command"

# Update the JSON with the modified command
echo "$input" | jq --arg cmd "$modified_command" '.command = $cmd'
