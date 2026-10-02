---
name: helios-disk-cleanup
description: Use when the disk is filling up, df shows high usage, or the user asks to clean up Helios worktrees, the Go build cache, or old images in the local k3d registry (k3d-registry.localhost). Also use for "prune worktrees", "remove merged worktrees", "free disk space", or "trim registry tags".
---

# Helios Disk Cleanup

Three things fill this laptop's disk, in order of how fast they grow:

| Source | Why it grows | Lever |
|---|---|---|
| `~/.cache/go-build` | Go keys cache entries by source path, so every worktree adds a full Helios build. 50G+ per hour when agents vet or test across worktrees. Go only trims entries unused for 5 days. | `scripts/go-cache-trim.sh`, run hourly by a systemd user timer |
| k3d registry volume | Tilt pushes a new `tilt-<hash>` tag on every rebuild, and the registry never deletes. | `scripts/registry-tags.sh` |
| Worktrees | About 2.7G each, left behind after PRs merge or close. | `scripts/worktree-audit.sh` |

Record `df -h /` before and after.
Every deletion here is irreversible, so each step's gate below is the review.

## Go build cache

The timer clears the cache whenever it passes 60G and no `compile` or `link` process is running.
Check it with `systemctl --user list-timers go-cache-trim.timer` and `journalctl --user -u go-cache-trim.service -n 5`.
If it is missing, install it:

```bash
D=~/.claude/skills/helios-disk-cleanup/systemd
systemctl --user link $D/go-cache-trim.service $D/go-cache-trim.timer
systemctl --user enable --now go-cache-trim.timer
```

For a manual clear, run `scripts/go-cache-trim.sh 0`.
Do not set `GOFLAGS=-trimpath` globally to share cache entries across worktrees.
`radagast/kube_crd_persistence_envtest_test.go` and `tool/testscope/driver/driver.go` find files through `runtime.Caller` paths, and those break under `-trimpath`.

## Worktrees

1. Run `scripts/worktree-audit.sh`.
   It reads paths from `git worktree list`, never hand-typed ones, since some live under `~/.cursor/worktrees/helios/`.
2. The bucket is advice, not permission:
   - `hold-in-use`: a process has its cwd inside the worktree. Never remove.
   - `hold-wip`: tracked uncommitted edits. Show `git -C <wt> status --short` and `git -C <wt> diff --stat`, and get the user's decision.
   - `hold-orphan-commits`: HEAD is on no branch, so its commits are lost on removal. Get a decision.
   - `hold-open-pr`: keep.
   - `verify-recent-chat`: a Claude or Cursor transcript touched it in the last 4 days. Ask the user whether that session is still active.
   - `safe`: PR merged or closed, or HEAD is in master.
   - `check-ticket`: no PR, but the branch names a Jira key. Look it up with the Atlassian MCP. If the ticket is Done or Closed, treat the row as `safe`. Otherwise treat it as `review`.
   - `review`: no PR and no ticket. Ask the user.
   - `missing-dir`: the directory is already gone. `git worktree prune` clears it.
3. Show the user the rows you plan to remove and wait for confirmation.
4. Remove each confirmed worktree with `git worktree remove <path>`.
   That keeps branch refs, so committed work survives.
   Without `--force`, git refuses on any uncommitted change, which is the last guard.
   Use `--force` only for `scratch:N` rows after naming the untracked files to the user.
   Finish with `git worktree prune`.

## Registry tags

Run through direnv so kubectl has the kubeconfig:

```bash
direnv exec ~/projects/helios ~/.claude/skills/helios-disk-cleanup/scripts/registry-tags.sh          # audit
direnv exec ~/projects/helios ~/.claude/skills/helios-disk-cleanup/scripts/registry-tags.sh --apply  # prune
```

The audit marks a tag `DELETE` only if all of these hold:
- No pod uses its tag or digest.
- No worktree's tracked files mention it.
- It is not among the newest `KEEP_NEWEST` tags (default 3) of its repo.
- It was pushed more than `KEEP_DAYS` days ago (default 3).

The script refuses to run without a running k3d cluster that has Helios pods, since then it cannot prove a tag is unused.
`--apply` refuses while a Tilt run, image build, or push is active, because a push racing garbage collection loses layers.
It then deletes the tags, runs `registry garbage-collect --delete-untagged`, and restarts the registry.

Show the user the audit's verdict counts and the largest repos before running `--apply`.
If a pod later fails with `ImagePullBackOff` on a deleted tag, rerun `tilt up` to rebuild it.

## Reply

Report `df -h /` before and after, what each step freed, and each worktree held back with its reason.
