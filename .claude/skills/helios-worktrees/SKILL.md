---
name: helios-worktrees
description: Use when creating, entering, repairing, or reasoning about git worktrees in the Helios repo.
---

# Helios Worktrees

## Creating Worktrees

When creating a worktree for the Helios repo, use the user's `wta` alias from an interactive shell instead of `git worktree add`.

```bash
wta chi/example-branch origin/master
```

Why: `wta` wraps worktree creation with Helios-specific setup, including `.envrc.private`, `direnv allow`, generated local-file symlinks, and frontend dependency setup. Raw `git worktree add` can create worktrees that look valid but later fail during commands like `make frontend-start`.

## Existing Worktrees

If already inside a worktree, use it as-is. Do not recreate it just to satisfy this skill.

If a Helios worktree is missing setup files, repair it by mirroring the behavior of `wta` rather than layering unrelated fixes. At minimum, check `.envrc.private`, `direnv allow`, and `test/kubeconfig.yml`.
