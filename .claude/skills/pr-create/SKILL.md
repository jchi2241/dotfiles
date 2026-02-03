---
name: pr-create
description: Create pull requests with well-written summaries. Use when the user asks to create a PR, open a pull request, or push changes for review.
allowed-tools: Bash(git status:*) Bash(git log:*) Bash(git branch:*) Bash(git rev-parse:*) Bash(git diff:*) Bash(gh pr:*) Bash(~/.claude/skills/pr-create/scripts/:*) Read
---

# Create Pull Request

Create a PR for the current branch. You have access to the full conversation history.

**Do NOT make any code changes, commits, or edits. Your sole responsibility is to generate the PR summary and create the PR.**

## Process

1. **Check state** - Run the script below to get branch info, commits, and check for uncommitted changes:
   ```
   ~/.claude/skills/pr-create/scripts/pr-state.sh
   ```
2. **If uncommitted changes exist** - Ask the user if they want to continue anyway
3. **Understand the why** - Review the conversation history to understand the purpose and motivation behind the changes
4. **Draft PR** - Combine conversation context + commits to write a meaningful title and summary
5. **Push if needed** - Use the safe push script (rejects force pushes):
   ```
   ~/.claude/skills/pr-create/scripts/safe-push.sh -u origin HEAD
   ```
6. **Create PR** - Use `gh pr create` with the drafted content

## PR Title Format (helios repo)

`[category:type] Description`

- Categories: operator, autoscale, cellagent, frontend, backend, misc, backup, nova, hotfix
- Types: feature, fix, improvement, chore, test, ci, localdev

## PR Summary (helios repo)

```
## Summary
(1-3 sentences on PURPOSE and IMPACT, not line-by-line changes)

## Test Plan
(How was this tested? Use `[INSERT VIDEO]` for frontend PRs)

## Deployment Plan
- Customer impact: Yes/No
- Rollout Plan: (feature flags, gradual rollout, etc.)
- Rollback Plan: (how to revert)
- Rollback Tested: Yes/No

## Subscribers
(optional - people interested but not required to review)

## JIRA Issues
(JIRA IDs, use `MCDB-NNNN #closes` in PR title for auto-close)
```

Rules:
- Under 300 words total
- Use `[TODO: ...]` for missing information - never fabricate

## Important

- **Do NOT make any code changes**
- **Do NOT create commits**
- **Do NOT amend commits**
- Only generate the PR summary and create the PR
