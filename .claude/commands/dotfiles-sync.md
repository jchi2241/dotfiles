---
description: Commit and push dotfiles configuration changes
allowed-tools: Bash(git:*), Bash(cd:*), Bash(~/.dotfiles/scripts/check-claude-skills.py), Read
---

# Dotfiles Sync

Commit every pending change in `~/.dotfiles`, grouped into logical commits, and push. Do not ask for confirmation.

## Step 1: Gather

!`cd ~/.dotfiles && git status --short`

!`cd ~/.dotfiles && git diff --stat`

!`~/.dotfiles/scripts/check-claude-skills.py`

!`cd ~/.dotfiles && git diff`

!`cd ~/.dotfiles && git log --oneline -10`

Read untracked files before committing them. If the skills check reports problems, fix them first; the pre-commit hook runs the same check.

## Step 2: Group

Split the changes into commits by intent, not by file:

- One commit per independent change: a new skill, a workflow change across several skills, a settings change, an unrelated tool or alias.
- Files that only make sense together (a skill and the CLAUDE.md row that indexes it, a reference rename and its callers) go in the same commit.
- A file with hunks from two changes gets split with `git add -p` style staging (`git apply --cached` on a filtered patch); never commit a half-change that breaks the skills check.
- One commit is fine when everything is one change.

Order commits so each one passes the skills check on its own.

## Step 3: Commit and push

For each group, stage only its files or hunks and commit.
Message style matches `git log`: one imperative subject line, under about 72 characters, naming what changed and why when it fits. No body unless the subject can't carry it. No co-author trailers.

Then `git push`. If the push is rejected, `git pull --rebase` and push again; stop and report on a conflict.

Never commit a file that looks like a secret (keys, tokens, `.env`, credentials); leave it unstaged and report it.

## Step 4: Report

List each commit's hash and subject, the push result, and anything left uncommitted with the reason.
