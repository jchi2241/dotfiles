---
description: Review and push dotfiles configuration changes
allowed-tools: Bash(git:*), Bash(cd:*), Read, AskUserQuestion
---

# Dotfiles Sync

Review pending changes in the dotfiles repository and optionally commit and push them.

## Step 1: Check for changes

Run these commands to gather the current state:

!`cd ~/.dotfiles && git status --short`

!`cd ~/.dotfiles && git diff --stat`

## Step 2: Show detailed changes

For each modified file, show the diff:

!`cd ~/.dotfiles && git diff`

## Step 3: Summarize and confirm

Provide a clear summary of:
- Which files were modified
- What the changes do (brief description)
- Any new untracked files

Then ask the user:
- Whether to proceed with committing and pushing
- What commit message to use (suggest one based on the changes)

## Step 4: Execute (only after confirmation)

After user confirms:
1. Stage all changes: `git add -A`
2. Commit with the agreed message
3. Push to remote
4. Report success with the commit hash
