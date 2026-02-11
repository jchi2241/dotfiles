---
name: stacked-branches
description: Use when implementing multi-phase plans that need separate PRs per phase, stacked branch isolation, or worktree-based plan execution
---

# Stacked Branches

## Overview

Each phase of an implementation plan gets its own branch, stacked on the previous phase's tip. Commits are prefixed with phase/task identifiers so rebase operations are unambiguous when earlier PRs merge.

## When to Use

- Implementing a multi-phase plan where each phase should be a separate PR
- You need clean boundaries between phases for code review
- Rebasing will be needed as earlier PRs merge to main

## Quick Reference

| Element | Convention | Example |
|---------|-----------|---------|
| Plan slug | Plan filename, drop date + `.md` | `2026-02-09_add-auth.md` → `add-auth` |
| Branch name | `chi/<slug>-phase-N` | `chi/add-auth-phase-2` |
| Commit prefix | `[PN/TM]` (phase N, task M) | `[P2/T4] Add login page` |
| Commit max | 50 chars total | |

## Two Modes

### Branch-only (default)

Create stacked branches directly in the current repo. No worktree.

### Worktree isolation

Work in a worktree for isolated development. Use when:
- Already in a worktree (auto-detected — use it as-is)
- User explicitly requests worktree isolation

Worktree creation is handled externally by the user (e.g., `wta` alias). Not this skill's job.

## Branch Lifecycle

### 1. Setup (before Phase 1)

```bash
SLUG="add-auth"
```

**Branch-only:**
```bash
git checkout -b "chi/${SLUG}-phase-1"
```

**Worktree isolation:** User creates worktree externally, then:
```bash
git checkout -b "chi/${SLUG}-phase-1"
```

### 2. Phase Boundary (after Phase N complete, before Phase N+1)

```bash
# Current branch: chi/<slug>-phase-N (all phase-N work committed)
# Create next branch stacked on current tip
git checkout -b "chi/${SLUG}-phase-$((N+1))"
```

Phase N+1 starts from Phase N's tip — this is what makes it stacked.

### 3. PRs After All Phases

Each phase branch targets the previous phase:

- Phase 1 PR: `chi/<slug>-phase-1` → `main`
- Phase 2 PR: `chi/<slug>-phase-2` → `chi/<slug>-phase-1`
- Phase N PR: `chi/<slug>-phase-N` → `chi/<slug>-phase-(N-1)`

### 4. Cascading Rebase When Earlier PRs Merge

When phase-1 merges to main:

1. Rebase phase-2 onto main: `git rebase main chi/<slug>-phase-2`
2. Commits prefixed `[P1/*]` are from phase-1 — git handles duplicates during rebase
3. Retarget phase-2 PR to `main`
4. Repeat cascade for subsequent phases

## Commit Message Format

```
[PN/TM] Brief imperative description
```

- `PN` = phase number, `TM` = task number (from plan)
- Max 50 characters total (prefix + space + description)
- Imperative mood: "Add", "Fix", "Update"

Examples:

```
[P1/T1] Add user model schema
[P1/T2] Add user API routes
[P2/T3] Add auth middleware
[P2/T4] Add login page component
[P3/T5] Add e2e auth tests
```

## Resume Handling

When resuming an interrupted implementation:

1. If worktree mode: check `git worktree list | grep <slug>`, cd into it
2. If branch-only: check current branch with `git branch --show-current`
3. If on correct phase branch, continue
4. If not, checkout the appropriate phase branch

## Common Mistakes

- Creating phase-2 branch from `main` instead of phase-1's tip (breaks stacking)
- Forgetting the commit prefix (makes rebase phase identification impossible)
- Committing without the task number (ambiguous phase membership)
