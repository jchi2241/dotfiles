---
name: commit
description: Use when the user asks to commit changes, save work, create a commit, or after completing code modifications that should be committed.
allowed-tools: Bash(git status:*) Bash(git diff:*) Bash(git add:*) Bash(git commit:*) Bash(git log:*)
---

# Commit Changes

Create atomic, well-messaged git commits from session changes. Core principle: each commit should be a logical unit with a concise message written as if the user authored it.

## Arguments

User-provided instructions override defaults. Examples:
- `/commit` - Follow standard process (may create multiple commits)
- `/commit single commit` - Create exactly one commit for all changes
- `/commit message: Fix auth bug` - Use the provided commit message
- `/commit skip approval` - Commit without asking for confirmation

When arguments are provided, adapt the process accordingly. User intent takes precedence.

## Quick Reference

| Rule | Example |
|------|---------|
| One line, max 50 chars | `Fix login redirect` |
| With plan prefix: `[PN/TM]` | `[P1/T2] Add auth endpoint` |
| Imperative mood | "Add", "Fix", "Update" (not "Added", "Fixed") |
| No trailing period | `Add auth endpoint` |
| No co-author/attribution | No "Co-Authored-By", no "Generated with Claude" |
| Never `git push` | Local commits only |
| Never `git add .` or `-A` | Stage specific files by name |

## Commit Message Prefixes (Helios)

In the helios repo, the first commit on a branch uses the PR title format `[category:type] Description` (e.g., `[backend:fix] Fix auth bug`). Subsequent commits on the same branch use plain messages without the prefix (e.g., `Gate batch agent domain auth`). Check `git log` to see if a prefixed commit already exists on the branch.

## Process

1. **Understand what changed:**
   - Review the conversation history
   - Run `git status` to see current changes
   - Run `git diff` to understand the modifications
   - Consider whether changes should be one commit or multiple logical commits

2. **Plan your commit(s):**
   - Identify which files belong together
   - Draft clear commit messages (max 30 chars each)
   - Group related changes into atomic commits

3. **Present your plan to the user:**
   - List the files you plan to add for each commit
   - Show the commit message(s) you'll use
   - Ask: "I plan to create [N] commit(s) with these changes. Shall I proceed?"

4. **Execute upon confirmation:**
   - Use `git add` with specific files (never use `-A` or `.`)
   - Create commits with your planned messages
   - Show the result with `git log --oneline -n [number]`

## Important

- **NEVER run `git push`** - local commits only
- **NEVER amend existing commits** unless explicitly requested
- No co-author information or Claude attribution of any kind
- Write commit messages as if the user wrote them

## Common Mistakes

- Using `git add .` or `-A` instead of staging specific files
- Writing past tense ("Fixed bug") instead of imperative ("Fix bug")
- Exceeding 30 characters in the commit message
- Pushing to remote (this skill is local-only)
- Adding "Co-Authored-By" or "Generated with Claude" lines
