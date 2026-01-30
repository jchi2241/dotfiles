---
description: Set session context to work within a specific git worktree
allowed-tools: Bash(git:*), Read
---

# Worktree Context

Set the working context for this session to a specific git worktree.

**Argument:** `$ARGUMENTS` (path to the worktree directory)

## Step 1: Validate the worktree

Verify the provided path is a valid git worktree:

!`cd "$ARGUMENTS" && git rev-parse --is-inside-work-tree && git worktree list`

!`cd "$ARGUMENTS" && git rev-parse --show-toplevel`

## Step 2: Gather worktree info

Get the current branch and upstream info:

!`cd "$ARGUMENTS" && git branch --show-current`

!`cd "$ARGUMENTS" && git remote -v`

## Step 3: Confirm context

After validating, inform the user:

**IMPORTANT SESSION CONTEXT:**

From this point forward, all work in this session is scoped to:
- **Worktree path:** The validated worktree directory
- **Branch:** The branch shown above
- **Repository:** The repository this worktree belongs to

All file operations, git commands, builds, and other actions should be executed within or relative to this worktree directory, NOT the main repository checkout.

When running commands that require the repository context (like `make`, `go build`, etc.), always use the worktree path as the working directory.

Confirm to the user that the session is now scoped to the worktree and ask if they have a specific task to work on.
