---
description: Resume implementation of an in-progress plan in a fresh session
argument-hint: [plan file path (optional)]
model: opus
---

# Continue Plan

Resume implementation of an in-progress plan from the next incomplete phase. Designed for multi-session workflows where each phase runs in a fresh context window.

**Optional argument:** Path to plan file. If omitted, scans for in-progress plans.

---

## Step 1: Find the Plan

**If a plan path is provided in `$ARGUMENTS`:** Use it directly. Skip to Step 2.

**Otherwise, discover in-progress plans:**

1. Scan `~/.claude/thoughts/plans/` for `.md` files
2. Read the YAML frontmatter of each file
3. Filter for `status: in_progress`
4. Sort by modification time (newest first)

**If no plans found:** Report:
```
No in-progress plans found in ~/.claude/thoughts/plans/.

To create a plan: /create-plan
To start a pending plan: /implement-plan <path>
```

**If one plan found:** Auto-select it.

**If multiple plans found:** Present choices to the user:

```
## In-Progress Plans

1. [title] — Phase [N]/[total], [X]/[Y] tasks complete
   Path: ~/.claude/thoughts/plans/YYYY-MM-DD_feature.md

2. [title] — Phase [N]/[total], [X]/[Y] tasks complete
   Path: ~/.claude/thoughts/plans/YYYY-MM-DD_other.md

Which plan to continue?
```

Wait for user selection.

---

## Step 2: Load Plan and Verify State

1. Read the selected plan file completely
2. Extract from frontmatter:
   - `task_list_id`
   - `phases_total`, `phases_complete`
   - `tasks_total`, `tasks_complete`
   - `spec` path (if present)
   - `research_doc` path (if present)
3. Read task statuses from `~/.claude/tasks/<task_list_id>/` (JSON files)
4. Reconcile: verify frontmatter counters match actual task file statuses. If they diverge, trust the task files and note the discrepancy.
5. Identify current phase (first phase with incomplete tasks)

**Detect Task API mode:** Call `TaskList`. If results match the plan's tasks, use Task APIs. Otherwise, use JSON fallback from `~/.claude/tasks/<task_list_id>/`.

**If all tasks are complete:**
```
All tasks in this plan are already complete.
Run /review-implementation <plan_path> for a final review, or /pr-create.
```
Stop.

**Otherwise, report:**

```
## Resuming: [plan title]

Plan: [path]
Task list: ~/.claude/tasks/<uuid>/
Mode: [Task APIs / JSON fallback]

Progress: Phase [N]/[total], [X]/[Y] tasks complete
Current phase: Phase [N] — [phase name]
Remaining tasks in phase: [count]

Proceeding with implementation...
```

---

## Step 3: Execute

Delegate to `/implement-plan` in **deliberate mode**. The implementation process is identical — follow the same steps defined in `/implement-plan --deliberate`:

1. **Cross-phase integration check** (Step 1a) — since we're resuming, this always runs (unless Phase 1)
2. **Branch setup** (Step 1b) — verify/create the phase branch
3. **Execute tasks** (Step 2) — with batch checkpoints every 3 tasks
4. **Phase completion** (Step 3) — cross-task integration review, plan update, session break

Deliberate mode ensures the session ends after the current phase completes, keeping each session's context clean.

**Pass to implementation:** plan path, spec path, current phase number, task list ID, API mode.

---

## User's Arguments

$ARGUMENTS
