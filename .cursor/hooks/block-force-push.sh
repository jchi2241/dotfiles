#!/bin/bash
# Block force push operations - equivalent to Claude Code PreToolUse hook
# Reads JSON input from stdin and blocks git push with force flags

input=$(cat)
command=$(echo "$input" | jq -r '.command // empty')

# Check for force push flags
if echo "$command" | grep -qP 'git\s+push\s+.*(-f|--force|--force-with-lease)'; then
    cat << 'EOF'
{
  "continue": true,
  "permission": "deny",
  "user_message": "Force push is blocked by hook policy.",
  "agent_message": "BLOCKED: Force push is not allowed. The command contained -f, --force, or --force-with-lease flags. Ask the user to run the force push manually if they really need it."
}
EOF
    exit 0
fi

# Allow non-force push git commands
cat << 'EOF'
{
  "continue": true,
  "permission": "allow"
}
EOF
exit 0
