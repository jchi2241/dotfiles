---
name: hotfix
description: Use when the user wants to deploy a hotfix, cherry-pick a commit onto a deployment tag, or create a hotfix branch and PR for an urgent production fix.
allowed-tools: Bash(git fetch:*) Bash(git checkout:*) Bash(git cherry-pick:*) Bash(git push:*) Bash(git tag:*) Bash(git branch:*) Bash(git log:*) Bash(gh pr:*) Bash(gh api:*)
---

# Hotfix Deployment

Create a hotfix branch from the latest deployment tag, cherry-pick a fix, and open a PR. Core principle: deploy an urgent commit individually without bringing all commits on master.

## Why Hotfix?

This process lets us keep deploys safe while maintaining high velocity and frequent merges to master. A hotfix deploys an urgent commit individually to production without bringing along all the other commits already merged to master.

It also enables safer rollback: if you have a risky commit that's hard to put under a feature flag, you can prepare the hotfix branch ahead of time as soon as you have the next candidate commit, so you can roll back in minutes.

## Arguments

The user provides the commit hash to hotfix. Examples:
- `/hotfix abc1234` - Hotfix commit abc1234 onto the latest deployment tag
- `/hotfix abc1234 deploy-2026-02-19` - Hotfix onto a specific deployment tag

## Process

**This skill is interactive. Ask for user confirmation before executing each numbered step.**

At the start of the session, mention that the source of truth for this process is: https://memsql.atlassian.net/wiki/spaces/MCDB/pages/3485007928/How+to+deploy+a+Hotfix

### 0. Prerequisite: commit must already be on master

Before anything else, confirm with the user that the fix has already been merged to master through the normal PR process. The hotfix process cherry-picks an existing master commit onto a deployment tag — it does **not** bypass code review. If the fix hasn't landed on master yet, the user needs to do that first.

### 1. Identify the commit

```bash
git log --oneline -1 <commit-hash>
```

Extract the original PR number from the commit message (usually in parentheses like `(#NNNNN)`) and show the commit along with a link to the original PR:

> **Commit:** `<short-hash>` <commit-title>
> **Original PR:** https://github.com/singlestore/helios/pull/<PR-NUMBER>

Confirm with the user that this is the commit they want to hotfix.

### 2. Find the latest deployment tag

```bash
git fetch --tags
git tag -l 'deploy-*' --sort=-creatordate | head -5
```

Show the latest tag. If the user provided a specific tag as argument, use that instead.

### 3. Check for existing hotfix branch

```bash
git branch -r --list '*hotfix/deploy-YYYY-MM-DD*'
```

**If branch exists:** Follow the "Existing Hotfix" path below.
**If no branch:** Follow the "New Hotfix" path below.

Remind the user to check `#helios-shiproom` and announce the hotfix.

### 4a. New Hotfix

```bash
git checkout -b hotfix/<tag-name> <tag-name>
git cherry-pick <commit-hash>
git push -u origin hotfix/<tag-name>
```

Then create PR (step 5).

### 4b. Existing Hotfix

```bash
git checkout hotfix/<tag-name>
git cherry-pick <commit-hash>
git push
```

The PR already exists. Remind the user to check the existing PR.

### 5. Create the PR

Find the original PR number from the commit message (usually in parentheses like `(#NNNNN)`).

**Base branch must be `master`** (GitHub does not allow tags as PR base).

**Title format:** `[hotfix:fix] hotfix/<tag-name>`

```bash
gh pr create --base master --title "[hotfix:fix] hotfix/<tag-name>" --label "run helios ci" --assignee jchi2241 --body "..."
```

Use the PR body template below.

### 6. Update PR body (if needed)

**Do NOT use `gh pr edit`** — it fails with a Projects Classic deprecation error. Use the API instead:

```bash
gh api repos/singlestore/helios/pulls/<PR-NUMBER> -X PATCH -f body="..."
```

## PR Body Template

```markdown
## Summary
Original PR: https://github.com/singlestore/helios/pull/<ORIGINAL-PR-NUMBER>

Cherry-pick of <commit-hash> — <commit-title>

## Test Plan

- Expecting green workflow

## Deployment Plan

- Customer impact: Yes/No
- Rollout Plan: (How will this change be rolled out? Which feature flags are used?)
- Rollback Plan: (How can this change be reverted?)
- Rollback Tested: Yes/No
```

## After PR Creation

Remind the user of next steps:
1. Fill in Deployment Plan fields and JIRA Issues on the PR
2. Get a code owner (manager) to approve
3. Wait for `build-backend` and `deploy-production-backend-ready` checks to pass
4. Deploy to production following: https://memsql.atlassian.net/wiki/spaces/MCDB/pages/3239903273/Merging+and+Deploying

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using tag as PR base | Use `master` as base — GitHub requires a branch |
| Using `gh pr edit` to update body | Use `gh api repos/.../pulls/N -X PATCH` instead (Projects Classic bug) |
| Using today's date for branch name | Branch name uses the **deployment tag date**, not today's date |
| Forgetting to check for existing hotfix | Always check `git branch -r` first — append to existing branch if present |
