---
description: Execute tasks from an implementation plan
argument-hint: [plan file path] [--yolo]
model: opus
---

# Implement Plan

Execute an implementation plan created by `/create-plan`, one PR at a time.

**Required argument:** Path to the plan file
**Optional flag:** `--yolo` — one `reviewers` agent per PR instead of the lanes, and no integration lane.

The plan file is the only progress state. A task is done when its "Actual Implementation" section is filled in. A PR is done when its section records a branch, a commit, and a PR URL. Rerun this command with the same plan to resume.

---

## When to stop

Run unattended. Stop only for:

- A chi-mode gate (`~/.claude/skills/chi-mode/SKILL.md`, Gates). Pushing and opening draft PRs follow the plan's `push:` field: `drafts` means the operator approved them, `ask` means queue them.
- A failed task, or a failed check that a fix round cannot clear.
- A deviation from the design document, or the same workaround in several PRs.
- A product call no experiment can settle.

Do not idle on a question. Keep working on PRs that do not depend on the answer, and put every open question into one `AskQuestion` at the next stop.

---

## Step 1: Load

1. **Read plan metadata only.** `Read` the plan with `limit: 50` for frontmatter and overview. `Grep` it for `^### Phase|^##### PR-|^- \*\*(Depends on|Tasks):|^### Task|^\*\*(Branch|Commit|PR):\*\*` with `-n` to get the structure. Never read the full plan; subagents read their own sections.
2. **Find the current PR:** the lowest PR, in dependency order, without a recorded PR URL (or, under `push: ask`, without a recorded commit).
3. Set `status: in_progress`. **Report** and continue:

```
Plan: [path]   Push policy: [drafts / ask]   Mode: [lanes / yolo]
Progress: [X]/[Y] PRs, [A]/[B] tasks. Current: Phase [N], PR-[M].
```

## Step 2: Branches

Work in a worktree (`helios-worktrees` skill), never the main `~/projects/helios` checkout. Stack conventions are in `gh-stack`.

One branch per PR section, named `<jira-key>/jchi/pr-<N>-<slug>`:

- A PR with no dependency starts from `origin/master`.
- A PR that depends on another stacks on that PR's branch.
- If the plan names a different base, use it.

## Step 3: Per PR

Take the lowest PR whose dependencies are done. PRs with no dependency between them may run in parallel, each in its own worktree, with at most two implementers or fixers at once. Put worktrees under `~/projects`, not `/tmp`, and give each one an `.envrc.private` with `use heavy_slots` (the `wta` copy sources the main repo's, which has it).

### 3a. Implement

Per task, follow `~/.claude/skills/subagent-driven-development/SKILL.md`. Dispatch one implementer (model role `code workers`) with a short pointer prompt; it reads its own template:

```
Read ~/.claude/skills/subagent-driven-development/implementer-prompt.md — that is your full instructions. Follow it.

Plan: [plan_path]
Task: [N]  (read "### Task [N]:" in the plan)
Spec: [spec_path]
Working dir: [dir]
Branch: [branch]
Commit prefix: [PN/PR-M/TK]

Completed dependencies:
- Task [N]: [one-line summary] — files: [paths]
(or "None")
```

Do not paste task text, read the spec for the subagent, or explore the code yourself. Your context is for coordination.

- Questions: answer from the plan or spec, then re-dispatch.
- `COMPLETED:` keep the one-line summary and files for dependent tasks.
- `FAILED:` stop and report.

Tasks in the same PR may run in parallel only when their "Files to Modify" lists do not overlap.

### 3b. Check the commit

Commit any leftover work with `/commit`. Then, on that one SHA, start both at once:

- **Targeted tests:** the PR's Verify tests, plus lint, on the touched packages and components only: `go test -p 2 ./named/pkg/`, and `cd frontend && pnpm run cct:run --spec <path>` per touched spec. Never `go build ./...` or the full suite per PR; leave wide coverage to CI.
- **Lanes:** per `~/.claude/skills/chi-mode/references/review-lanes.md`. Say the Risky call and its reason when you launch them. In `--yolo`, one `reviewers` agent instead.

Start the next PR's tasks while these run.

### 3c. Fix round

Triage per `review-lanes.md`. Put every real finding and every test failure into **one** fix commit per round, by a fresh fix subagent (model role `code workers`):

```
Fix these findings. Each behavior fix gets a test that fails without it.
Plan: [plan_path], PR-[M]. Working dir: [dir]. Branch: [branch].
Findings: /tmp/review/<pr>-*.md, entries [F1, F3, ...]; test failures: [paths or output].
Do not change code outside these fixes. Run the targeted tests. Commit.
Report: FIXED: [summary] or FAILED: [what could not be fixed]
```

Rerun the targeted tests and only the lanes the fix touches, per `review-lanes.md`. Repeat until no lane blocks.

### 3d. Draft PR

1. Under `push: drafts`, open the PR with `/pr-create`, as a draft, on the PR's base branch. Its Test Plan lists the targeted test results and the PR's live claims as `pending phase [N] verify`. Under `push: ask`, queue it for the next stop.
2. Record in the PR section:

```markdown
**Branch:** `<branch>`
**Commit:** `<sha>` (tests and lanes pass)
**PR:** [URL, or "queued"]
```

3. Increment `prs_complete`, and `tasks_complete` per task.

## Step 4: Per phase

After every PR in the phase has a recorded commit:

1. **Integration lane.** One fresh agent (model role `reviewers`) with the integration brief from `review-lanes.md`, given the phase's branches and head SHAs, the plan path, and the design document. Skip in `--yolo`.
2. **Live verify.** Deploy the top of the phase's stack to the local stack once. Run the `verify-helios` skill on every live claim in the phase's PR sections, plus its regression and gates claims. Do not build, deploy, or run Tilt alongside another heavy build.
3. **Record evidence** in each PR's Test Plan and the plan. A failed claim goes back to that PR as a fix round (Step 3c), and only that claim reruns.
4. **Write the phase summary** at the end of the phase section:

```markdown
#### Phase [N] Summary
> Completed YYYY-MM-DD

**PRs:** PR-[M] `<branch>` [URL], ...
**Deviations from plan:** [what changed and why]
**Gotchas for the next phase:** [anything a fresh agent should know]
**Integration lane:** [NO-BLOCK / findings]
**Live verify:** [receipts path, verdict, SHA per PR]
```

5. Increment `phases_complete`. Ask the queued questions and pushes in one `AskQuestion`, then continue with the next phase. Marking a PR ready for review is the operator's call.

## Step 5: Done

1. Set `status: complete` and add a Changelog entry.
2. Report every PR, its phase, and its link, then the Slack summary:

```
hi team, [plan title] ([feature subtitle]) is ready for review: [N] stacked PRs across [repo(s)] covering [brief list of areas touched].

*[repo name]:*
1. [PR title](PR URL)
2. [PR title](PR URL)

*PRD*: [google doc URL from spec frontmatter, if available]

appreciate your time to take a look at these, thanks!
```

Read each title with `gh pr view <URL> --json title`. Group PRs by repo under italic headers. No per-PR descriptions. Lowercase and work-casual, with colons, not em dashes.

---

## User's Plan Path

$ARGUMENTS
