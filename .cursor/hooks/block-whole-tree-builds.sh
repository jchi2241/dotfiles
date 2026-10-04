#!/bin/bash
# Refuse whole-tree builds and test runs so agents scope them to the packages
# or specs they touched. Works as a Cursor beforeShellExecution hook (JSON
# deny on stdout) and a Claude Code PreToolUse Bash hook (exit 2 + stderr).

input=$(cat)
command=$(echo "$input" | jq -r '.command // .tool_input.command // empty')
# Cursor also runs ~/.claude/settings.json hooks (as preToolUse, with
# cursor_version set); answer those in Cursor's format so the reason shows.
claude=$(echo "$input" | jq -r 'if has("cursor_version") then "" else "1" end')

reason=""
if echo "$command" | grep -qP '\bgo\s+(build|test|vet)\b[^;&|]*(\s|^)(\./\.\.\.|\.\.\.|all)(\s|$|;|&|\|)'; then
	reason="Whole-module Go builds and tests (./..., all) are blocked. Name the packages the change touches, e.g. go test -p 2 ./graph/server/public/ ./billing/analystbudget/..."
elif echo "$command" | grep -qP '\bcypress\s+run\b' && ! echo "$command" | grep -qP '\-\-spec\b'; then
	reason="Cypress runs without --spec are blocked. Run the specs the change touches with --spec <path>."
fi

if [[ -z $reason ]]; then
	[[ -n $claude ]] && exit 0
	echo '{ "continue": true, "permission": "allow" }'
	exit 0
fi

if [[ -n $claude ]]; then
	echo "BLOCKED: $reason" >&2
	exit 2
fi
jq -n --arg r "$reason" '{continue: true, permission: "deny", user_message: ("Blocked by hook: " + $r), agent_message: ("BLOCKED: " + $r)}'
exit 0
