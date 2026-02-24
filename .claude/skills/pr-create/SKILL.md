---
name: pr-create
description: Use when the user asks to create a PR, open a pull request, or push changes for review.
allowed-tools: Bash(git status:*) Bash(git log:*) Bash(git branch:*) Bash(git rev-parse:*) Bash(git diff:*) Bash(gh pr:*) Bash(~/.claude/skills/pr-create/scripts/:*) Read
---

# Create Pull Request

Generate a well-structured PR from branch history and conversation context. Core principle: PR summaries explain purpose and impact, not line-by-line changes.

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
6. **Create PR** - Use `gh pr create` with the drafted content and `--assignee jchi2241`

## PR Title Format

> The format below applies to the helios repository. For other repos, use a conventional short title.

`[category:type] Description`

- Categories: operator, autoscale, cellagent, frontend, backend, misc, backup, nova, hotfix
- Types: feature, fix, improvement, chore, test, ci, localdev

## PR Summary

> The template below applies to the helios repository. For other repos, use a simple Summary + Test Plan format.

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

Example — what/why, not how:
- Bad: "Added a `retryCount` field to `BackupConfig` and updated `runBackup()` to loop up to N times"
- Good: "Backup jobs now retry on transient failures, reducing false alerts from one-off network blips"

Rules:
- Under 300 words total
- Use `[TODO: ...]` for missing information - never fabricate

## Important

- **Do NOT make any code changes**
- **Do NOT create commits**
- **Do NOT amend commits**
- Only generate the PR summary and create the PR

## Common Mistakes

- Fabricating test results instead of using `[TODO: ...]`
- Making code changes or amending commits (this skill is summary-only)
- Force pushing (use the safe-push script which rejects force pushes)
- Describing line-by-line changes instead of purpose and impact
