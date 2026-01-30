---
name: commit
description: Create git commits with succinct messages. Use when the user asks to commit changes, save work, create a commit, or after completing code modifications that should be committed.
allowed-tools: Bash(git status:*) Bash(git diff:*) Bash(git add:*) Bash(git commit:*) Bash(git log:*)
---

# Commit Changes

You are tasked with creating git commits for the changes made during this session.

## NEVER RUN

**NEVER run `git push`** - this skill is for local commits only. If the user wants to push, they must do it themselves or use a different workflow.

## Arguments

User-provided instructions override defaults. Examples:
- `/commit` - Follow standard process (may create multiple commits)
- `/commit single commit` - Create exactly one commit for all changes
- `/commit message: Fix auth bug` - Use the provided commit message
- `/commit skip approval` - Commit without asking for confirmation

When arguments are provided, adapt the process accordingly. User intent takes precedence.

## Commit Message Rules

- **One line only, max 30 characters**
- Imperative mood ("Add", "Fix", "Update", not "Added", "Fixed")
- No periods at the end
- Examples: `Fix login redirect`, `Add auth endpoint`

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
- **NEVER add co-author information or Claude attribution**
- Commits should be authored solely by the user
- Do not include any "Generated with Claude" messages
- Do not add "Co-Authored-By" lines
- Write commit messages as if the user wrote them
- **NEVER amend existing commits** unless explicitly requested

## Remember

- You have the full context of what was done in this session
- Group related changes together
- Keep commits focused and atomic when possible
- The user trusts your judgment - they asked you to commit
