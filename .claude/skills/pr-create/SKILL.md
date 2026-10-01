---
name: pr-create
description: Use when the user asks to create a PR, open a pull request, or push changes for review.
allowed-tools: Bash(git status:*) Bash(git log:*) Bash(git branch:*) Bash(git rev-parse:*) Bash(git diff:*) Bash(gh pr:*) Bash(~/.claude/skills/pr-create/scripts/:*) Read
---

# Create Pull Request

Generate a well-structured PR from branch history and conversation context. Core principle: PR summaries explain purpose and impact, not line-by-line changes.

Your job is the PR title, body, push, and `gh pr create`. Do not change product code, commit, or amend. For UI screenshots, use `helios-ui-visual-proof` before this skill, then `pr-image-upload`.

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

Follow `writing-pr-descriptions` for Summary / Test Plan / Deployment Plan prose.

> The headings below apply to the helios repository. For other repos, use a simple Summary + Test Plan format.

```
## Summary
(at most 2 sentences — see writing-pr-descriptions)

## Test Plan
(this PR's targeted tests, then walkthrough / visual proof; for UI, capture via `helios-ui-visual-proof` then `pr-image-upload`)

## Deployment Plan
- Customer impact: Yes/No
- Rollout Plan: (feature flags, gradual rollout, etc.)
- Rollback Plan: (only if a well-defined feature flag / Codegate exists; default to N/A if only "Revert PR")
- Rollback Tested: (Yes/No if feature flag/Codegate exists, N/A if Rollback Plan is N/A)

## Subscribers
(optional - people interested but not required to review)

## JIRA Issues
(JIRA IDs, use `MCDB-NNNN #closes` in PR title for auto-close)
```

- Use `[TODO: ...]` for missing information - never fabricate

## Important

- **Do NOT make product code changes, commits, or amends**
- Only generate the PR summary and create the PR

## Common Mistakes

- Fabricating test results instead of using `[TODO: ...]`
- Making product code changes or amending commits (this skill is summary-only)
- Force pushing (use the safe-push script which rejects force pushes)
- Describing line-by-line changes instead of purpose and impact
