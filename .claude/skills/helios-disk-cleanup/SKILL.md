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

Every deletion here is irreversible.
Run the audits, show one proposal with before and after disk numbers (see Proposal gate), and delete nothing until the user confirms it.

## Go build cache

The timer clears the cache whenever it passes 60G and no `compile` or `link` process is running.
Check it with `systemctl --user list-timers go-cache-trim.timer` and `journalctl --user -u go-cache-trim.service -n 5`.
If it is missing, install it:

```bash
D=~/.claude/skills/helios-disk-cleanup/systemd
systemctl --user link $D/go-cache-trim.service $D/go-cache-trim.timer
systemctl --user enable --now go-cache-trim.timer
```

For a manual clear, add it to the proposal (current `du` to about 0), and run `scripts/go-cache-trim.sh 0` only after confirmation.
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
3. Put the rows you plan to remove in the proposal and wait for confirmation.
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

Put the audit's verdict counts, the largest repos, and the registry's `du` in the proposal, and do not run `--apply` until the user confirms.
If a pod later fails with `ImagePullBackOff` on a deleted tag, rerun `tilt up` to rebuild it.

## Proposal gate

After all audits, show one proposal and stop.
Do not remove, prune, trim, or `--apply` anything until the user confirms.

Gather the baseline first:
- Disk: `df -h /` (Used, Size, Use%).
- Go cache: `du -sh ~/.cache/go-build`.
- Registry: `docker exec k3d-registry.localhost du -sh /var/lib/registry`.
- Worktrees: the SIZE column from `worktree-audit.sh`.

Render it as plain markdown in this shape, with real numbers.
Do not wrap it in a code fence; the fence below only shows the source.

```markdown
### Cleanup proposal: nothing is deleted until you confirm

████████████░░░░░░░░ 532G / 914G (62%) **before**  
██████████░░░░░░░░░░ 437G / 914G (50%) **after**  
↓ **est. 95G freed**

| Step | Frees | Share |
|---|---|---|
| Worktrees: remove 2, prune 1 | 15.6G | ███░░░░░░░░░░░░░░░░░ |
| Registry: `--apply` 1128 tags | ≤79G | █████████████████░░░ |
| Go cache: skip, 43G < 60G cap | 0 | ░░░░░░░░░░░░░░░░░░░░ |

**Remove:** `helios-budget-stack-rebase` 14.0G (PR merged, generated files dirty), `helios-wt-billing-apptype` 1.6G (PR merged, clean)  
**Held back:** in use `/tmp/wt-fix-pr{1,5,8,34}` · open PR (8) · uncommitted work (5) · recent chat: MCDB-100995 (In Progress), 2 others  
**Blocked:** none (or "Registry: Tilt active, will be skipped")
```

Rules:
- Keep it condensed: use two trailing spaces for line breaks instead of blank lines between the disk lines, and no blank lines inside a group.
- Disk bars sit on adjacent lines, starting each line, with the used/total, percent, and a bold `before` or `after` label after the bar. Labels go after the bar because their different widths would otherwise misalign the bars in a proportional font. Do not write "used".
- Put the freed (or added) estimate on the line under both disk bars.
- Disk bars are 20 cells of `█` and `░`, each cell 5% (`round(Use% / 5)` filled).
- Steps go in a table. Share cells are 1/20 of the total freed (`round(step / total × 20)` filled). A skipped step is an empty bar.
- Use the Use% from `df`, not `used / size`, so the percent matches the terminal.
- After = Used − worktree sizes − registry `du` (only if applying) − go-cache `du` (only if clearing). Blocked or skipped steps count as 0.
- Label the registry figure `upper bound`, since garbage collection can reclaim less than its `du`.
- Under Held back, list every `hold-*` and `verify-recent-chat` worktree, grouped by bucket, with the reason.

## Reply

After running only the confirmed steps, report the same card with measured numbers, again as plain markdown, not in a code fence.
Rename `est.` to `actual`, give each step what it freed or why it was skipped, and note any gap over 10G from the estimate (for example, builds refilling the Go cache).

```markdown
████████████░░░░░░░░ 532G / 914G (62%) **before**  
█████████████░░░░░░░ 569G / 914G (66%) **after**  
↑ **actual 37G more used**

| Step | Freed | Share |
|---|---|---|
| Worktrees | 15.6G | ████████████████████ |
| Registry | 0 | ░░░░░░░░░░░░░░░░░░░░ skipped: Tilt active |
| Go cache | 0 | ░░░░░░░░░░░░░░░░░░░░ skipped: build running (now 111G) |
```
