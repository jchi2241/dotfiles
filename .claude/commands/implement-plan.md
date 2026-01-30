---
description: Execute tasks from an implementation plan
argument-hint: [plan file path]
model: opus
---

# Implement Plan

Execute tasks from an implementation plan created by the `create-plan` skill.

**Required argument:** Path to the plan file (e.g., `~/.claude/thoughts/plans/2026-01-28_feature-name.md`)

---

## Pre-flight Checks

Before implementing, verify:

1. **Plan file exists** at the provided path
2. **Task List path** is recorded in the plan header (e.g., `~/.claude/tasks/<uuid>/`)
3. **Tasks exist** - check the task list directory has JSON files

If any are missing, inform the user and stop.

---

## Task API vs JSON Fallback

The Task APIs (`TaskList`, `TaskUpdate`, etc.) only work if the session was started with the matching task list ID:

```bash
CLAUDE_CODE_TASK_LIST_ID=<uuid> claude
```

**Detection:** Call `TaskList` at the start. If it returns tasks matching the plan, use Task APIs. Otherwise, fall back to reading/writing JSON files directly.

### When Task APIs work (preferred):
- Use `TaskList` to view statuses
- Use `TaskUpdate` to change status to `in_progress` or `completed`
- Use `TaskGet` to read task details

### When falling back to JSON files:
- Read `~/.claude/tasks/<uuid>/*.json` to get task statuses
- Edit JSON files to update `"status"` field
- Task panel won't update, but progress is persisted

**Always inform the user** which mode you're operating in at the start.


---

## Implementation Process

### Step 1: Load Context

1. Read the plan file completely to get the task list ID
2. **Detect API mode:**
   - Call `TaskList` and check if returned tasks match the plan's tasks
   - If match: use Task APIs (inform user: "Task APIs active")
   - If no match: use JSON fallback (inform user: "Using JSON fallback - task panel won't update")
3. Get task statuses (via TaskList or by reading JSON files)
4. Identify which phase to work on (first phase with incomplete tasks)
5. Briefly state which phase/tasks are next:

```
Plan loaded. [Task APIs active / Using JSON fallback]
Phase [N] has [X] pending tasks ready to implement. Proceed?
```

**Wait for user confirmation before proceeding.**

### Step 2: Execute Tasks

For each unblocked, pending task in the current phase:

1. **Mark task as in_progress:**
   - Task APIs: `TaskUpdate` with `status: "in_progress"`
   - JSON fallback: Edit `~/.claude/tasks/<uuid>/<N>.json`, change `"status": "pending"` to `"status": "in_progress"`
2. **Launch a Task agent** (model: **opus**) with this prompt structure:

```
Implement Task [N] from the plan at [plan_path].

## Model Check (DO THIS FIRST)
If you are running on Opus 4.1 (model ID contains "claude-opus-4-1" or "claude-4-opus"), STOP IMMEDIATELY and return:
"MODEL_MISMATCH: Running on Opus 4.1. Retry with sonnet."

Do NOT proceed with implementation if you are Opus 4.1.

## Task Details
[Copy the full task section from the plan, including:]
- Description
- Files to Modify
- Implementation Notes
- Success Criteria

## Context
- Plan file: [path]
- Task group: [path]
- Research doc: [path if referenced in plan]

## Requirements
1. **Read the plan file first** to understand full context
2. **Write production-grade code** - follow existing patterns, include error handling
3. **Run verification commands** from Success Criteria
4. **After successful implementation**, update the plan file's "Actual Implementation" section for this task

## Important
- If you encounter blockers, document them in the plan and stop
- Do not modify code outside the scope of this task
- Follow existing code patterns exactly
```

3. **Handle MODEL_MISMATCH:** If the agent returns a MODEL_MISMATCH message, re-launch the task with `model: sonnet`.

4. **After agent completes**, mark task as completed:
   - Task APIs: `TaskUpdate` with `status: "completed"`
   - JSON fallback: Edit `~/.claude/tasks/<uuid>/<N>.json`, change `"status"` to `"completed"`
5. **Wait for each task to complete** before launching dependent tasks
6. **Launch independent tasks in parallel** when possible (same phase, no dependencies between them)

### Step 3: Phase Completion

After all tasks in a phase complete:

1. Run the phase's automated verification commands from the plan
2. Confirm all phase tasks are completed:
   - Task APIs: `TaskList` shows all phase tasks as completed
   - JSON fallback: All phase task JSON files have `"status": "completed"`
3. Report verification results briefly:

```
Phase [N] complete. Verification: [PASS/FAIL with details if failed]

Proceed to Phase [N+1], or pause for manual testing?
```

**Wait for user confirmation before proceeding to next phase.**

### Step 4: Plan Completion

After all phases complete:

1. Update the plan's Changelog with completion summary
2. Present final status

---

## Task Agent Requirements

Each task agent MUST:

1. **Read the full plan** before starting (for context)
2. **Read referenced research docs** if any
3. **Follow existing code patterns** - search for similar implementations
4. **Run all verification commands** in Success Criteria
5. **Update the plan file** with Actual Implementation details

**Note:** Task status updates (`in_progress` → `completed`) are handled by the parent executor, not by the task agent. The parent uses Task APIs when available, or edits JSON files as fallback.

---

## Error Handling

If a task fails:

1. Document the failure in the plan's Actual Implementation section
2. Do NOT mark the task as completed
3. Report to user with details:
   - What was attempted
   - What failed
   - Suggested remediation

The user can then:
- Fix the issue and re-run
- Modify the plan and re-run
- Skip the task (with explicit confirmation)

---

## Resuming Implementation

This skill supports resuming interrupted implementations:

1. Gets current task statuses (via TaskList or JSON files)
2. Skips tasks with status `completed`
3. Continues from first incomplete task in the earliest incomplete phase

**Tip:** For best experience when resuming, start the session with:
```bash
CLAUDE_CODE_TASK_LIST_ID=<uuid> claude
```
This enables the task panel to show progress.

---

## Example Usage

**With Task APIs (started with env var):**
```
$ CLAUDE_CODE_TASK_LIST_ID=47b60e77-035a-4e82-a7f4-a3c8b7660f79 claude

User: /implement-plan ~/.claude/thoughts/plans/2026-01-28_feedback-threads.md

Claude: [Reads plan, TaskList shows matching tasks]

Plan loaded. Task APIs active.
Phase 2 has 2 pending tasks ready to implement (Tasks 4-5). Proceed?
```

**With JSON fallback (no env var):**
```
$ claude

User: /implement-plan ~/.claude/thoughts/plans/2026-01-28_feedback-threads.md

Claude: [Reads plan, TaskList doesn't match, reads JSON files]

Plan loaded. Using JSON fallback - task panel won't update.
Phase 2 has 2 pending tasks ready to implement (Tasks 4-5). Proceed?
```

---

## User's Plan Path

$ARGUMENTS
