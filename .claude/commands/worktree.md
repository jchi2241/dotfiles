---
description: Set session context to work within a specific git worktree
allowed-tools: Bash(git:*), Bash(ls:*), Read
---

# Worktree Context

Set the working context for this session to a specific git worktree.

**Argument:** `$ARGUMENTS` (branch name pattern or path to the worktree directory)

## Step 1: Find the worktree

The argument can be:
1. A direct path (e.g., `/home/jchi/projects/helios-chi-feature`)
2. A branch name (e.g., `chi/feedback-p1-fix-auto-scroll`)
3. A partial match (e.g., `feedback-p1`)

Run `git worktree list` on each repository to find worktrees matching the pattern. Convert slashes to dashes for matching since worktree directories use dashes.

Repositories to search:
- ~/projects/helios
- ~/projects/heliosai
- ~/projects/singlestore-nexus
- ~/projects/unified-model-gateway

Run these commands to list all worktrees:

```bash
git -C ~/projects/helios worktree list
git -C ~/projects/heliosai worktree list
git -C ~/projects/singlestore-nexus worktree list
git -C ~/projects/unified-model-gateway worktree list
```

Then filter results for paths containing: `$ARGUMENTS` (with slashes converted to dashes)

## Step 2: Validate and gather info

From the output above, identify the worktree path. If multiple matches, pick the best one or ask user.

Then run these commands with the identified worktree path:

```bash
git -C PATH rev-parse --is-inside-work-tree
git -C PATH branch --show-current
git -C PATH log --oneline -3
```

## Step 3: Confirm context

After validating, inform the user:

**SESSION CONTEXT SET:**

From this point forward, all work in this session is scoped to:
- **Worktree path:** The validated worktree directory
- **Branch:** The branch shown above
- **Repository:** The repository this worktree belongs to

All file operations, git commands, builds, and other actions should be executed within or relative to this worktree directory, NOT the main repository checkout.

When running commands that require the repository context (like `make`, `go build`, etc.), always use the worktree path as the working directory.

Confirm to the user that the session is now scoped to the worktree and ask if they have a specific task to work on.
