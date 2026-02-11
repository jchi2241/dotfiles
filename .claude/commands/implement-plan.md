---
description: Execute tasks from an implementation plan
argument-hint: [plan file path] [--deliberate | --yolo]
model: opus
---

# Implement Plan

Execute tasks from an implementation plan created by the `create-plan` command.

**Required argument:** Path to the plan file
**Optional flags:** `--deliberate` | `--yolo` (default: standard mode)

---

## Mode Flags

Parse `$ARGUMENTS` for mode flags. The plan path is the first non-flag argument.

| Mode | Flag | Behavior |
|------|------|----------|
| **Standard** | _(default)_ | Full ceremony. Per-task two-stage review + cross-task integration review + batch checkpoints every 3 tasks. Single orchestrator session across all phases. |
| **Deliberate** | `--deliberate` | Everything in Standard + session ENDS after each phase. On resume, cross-phase integration check validates previous work before continuing. Use `/continue-plan` to resume in a fresh session. |
| **YOLO** | `--yolo` | Self-review only (no external reviews). Commits at end. No session breaks. Only stops on failures. |

**Parsing:** Split `$ARGUMENTS` on whitespace. Look for `--deliberate` or `--yolo`. Everything else is the plan file path. If both flags are present, error and ask user to pick one.

---

## Pre-flight Checks

Before implementing, verify:

1. **Plan file exists** at the provided path
2. **Read the plan file** completely — extract:
   - `task_list_id` from frontmatter
   - `spec` path from frontmatter (if present)
   - `research_doc` path from frontmatter (if present)
   - Phase structure and task breakdown
3. **Task List path** is recorded in the plan header
4. **Tasks exist** — check the task list directory has JSON files
5. **Derive plan slug** — from plan filename: strip date prefix and `.md` suffix (e.g., `2026-02-09_add-auth.md` → `add-auth`). This slug is used for worktree and branch naming.

If any required artifact is missing, inform the user and stop.

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

### Step 1: Load Context and Report Status

1. Read the plan file completely
2. Read the spec file (if referenced in frontmatter) — for phase review context later
3. **Detect API mode** (Task APIs vs JSON fallback)
4. Get task statuses
5. Identify current phase (first phase with incomplete tasks)
6. **Detect resume** — if any phases have all tasks completed, this is a resume
7. Report:

```
Plan loaded. [Task APIs active / Using JSON fallback]
Mode: [standard / deliberate / yolo]
Spec: [path or "none referenced"]
Progress: [X]/[Y] tasks complete, Phase [completed]/[total] phases complete
Current phase: Phase [N] — [phase name] ([X] pending tasks)
[If resuming in deliberate mode]: Resume detected — will run cross-phase integration check first.
```

**Wait for user confirmation before proceeding.**

### Step 1a: Cross-Phase Integration Check (deliberate mode resume only)

**When:** Deliberate mode, resuming at Phase 2+ (at least one completed phase exists). This runs at the **start of a fresh session** before any new work, validating that the previous phase's work is solid and the current phase's plan is still valid.

**Skip in:** Standard mode (single session, no cross-phase boundary), YOLO mode.

Spawn a **read-only** Task agent (model: **opus**, subagent_type: **general-purpose**):

```
You are a staff engineer verifying integration before starting Phase [N].

## Context
- Plan file: [plan_path] — read it completely
- Spec file: [spec_path] (if available)
- Most recently completed phase: Phase [N-1]

## Your Job
1. Read the plan's Phase [N-1] tasks and their "Actual Implementation" sections
2. Verify against the actual codebase:
   - Do the implementations match what was documented?
   - Are there any inconsistencies or regressions?
   - Has the codebase changed outside of the plan since the last session? (check git log for commits not attributable to plan tasks)
3. Check Phase [N]'s planned tasks:
   - Are they still valid given what Phase [N-1] actually implemented?
   - Any assumptions that no longer hold?
   - Do file paths and line references still match?

## Output Format
READY: [one-line summary — codebase is consistent, Phase N plan is valid]

or

ISSUES:
- [file:line] [description] [severity: blocking | warning]
- [Phase N adjustment] Task X: [what needs to change and why]

## Rules
- Read-only. Do not modify any files.
- Be terse. Only actionable findings.
- Focus on integration and plan validity, not style.
- Check EVERY file mentioned in the completed tasks, not a sample.
```

**Handle results:**

- **READY:** Report and proceed to branch setup (Step 1b).
- **ISSUES with blocking items:** Present issues to user. Wait for user decision before proceeding.
- **ISSUES with warnings only:** Report warnings, proceed.

### Step 1b: Branch Setup

**Uses: `stacked-branches` skill** — see `~/.claude/skills/stacked-branches/SKILL.md` for conventions.

**Detect environment:**

```bash
# Check if already in a worktree
git rev-parse --show-toplevel
git rev-parse --git-common-dir
# If these differ, we're in a worktree — use it as-is
```

**If already in a worktree:** Use it. Proceed to branch creation below.

**If NOT in a worktree:** Ask the user:
- **Worktree isolation** — user creates worktree externally (e.g., `wta`), then re-runs
- **Branch-only** — create branches in the current repo directly

**Branch creation (all flows):**

For Phase 1: `git checkout -b "chi/${SLUG}-phase-1"`
For resume (Phase N > 1): verify current branch matches expected phase, checkout if needed.

**Pass to all subagents:** working directory and current phase/task numbers for commit prefixes.

### Step 2: Execute Tasks in Current Phase

**Uses: `subagent-driven-development` skill** — see `~/.claude/skills/subagent-driven-development/SKILL.md` for the full per-task loop and prompt templates.

**Preparation:** Read the plan file once. Extract the full text of every task in the current phase (description, files to modify, implementation notes, success criteria). You will paste this text into subagent prompts — subagents should never read the plan file for task details.

**Batch size:** 3 tasks. After every 3 completed tasks within a phase, pause for a batch checkpoint (see Step 2f).

For each unblocked, pending task in the current phase:

#### 2a. Dispatch Implementer

1. **Mark task as in_progress** (Task APIs or JSON fallback)
2. **Prepare inline context** — extract from the plan:
   - Full task description, files to modify, implementation notes, success criteria
   - Relevant spec excerpts (architectural approach, data models, constraints)
   - Phase context (what phase, other tasks, dependencies)
3. **Launch implementer subagent** (model: **opus**, subagent_type: **general-purpose**) using the template in `~/.claude/skills/subagent-driven-development/implementer-prompt.md`. Paste all context inline.
4. **Handle response:**
   - If subagent asks questions → answer clearly, then re-dispatch with answers incorporated
   - If `COMPLETED:` → proceed to spec review (step 2b)
   - If `FAILED:` → do NOT mark completed, report failure to user with details, stop and wait for user input

#### 2b. Spec Compliance Review (skip in --yolo mode)

1. **Dispatch spec reviewer** (model: **opus**, subagent_type: **general-purpose**) using the template in `~/.claude/skills/subagent-driven-development/spec-reviewer-prompt.md`. Provide:
   - Full task requirements (pasted inline from plan)
   - Implementer's report (summary, files changed, self-review findings)
2. **Handle response:**
   - `✅ SPEC COMPLIANT` → proceed to code quality review (step 2c)
   - `❌ SPEC ISSUES` → dispatch fix subagent (step 2e) with the specific issues → re-dispatch spec reviewer → repeat until compliant

#### 2c. Code Quality Review (skip in --yolo mode)

1. **Dispatch code quality reviewer** (model: **opus**, subagent_type: **general-purpose**) using the template in `~/.claude/skills/subagent-driven-development/code-quality-reviewer-prompt.md`. Provide:
   - Task summary and files changed
2. **Handle response:**
   - `✅ QUALITY APPROVED` → mark task as completed
   - `❌ QUALITY ISSUES with blocking items` → dispatch fix subagent (step 2e) → re-dispatch quality reviewer → repeat until approved
   - `❌ QUALITY ISSUES with warnings only` → mark task as completed, note warnings

#### 2d. Parallel Execution

- **Launch independent tasks in parallel** when possible (same phase, no blocking dependencies, no overlapping files to modify)
- Each parallel task runs its own full review loop (2a → 2b → 2c)
- **Wait for dependent tasks** to complete before launching blocked tasks

#### 2e. Fix Subagent Protocol

When a reviewer finds issues, dispatch a fresh fix subagent (model: **opus**, subagent_type: **general-purpose**):

```
Fix the following issues found during [spec compliance / code quality] review.

## Original Task
[Brief task summary and files involved]

## Issues to Fix
[Paste reviewer's findings with file:line references]

## Requirements
1. Fix each issue listed above
2. Do not modify code outside the scope of these fixes
3. Run relevant tests to verify fixes
4. Commit your changes

Report: FIXED: [summary of changes] or FAILED: [what couldn't be fixed]
```

#### 2f. Batch Checkpoint

**After every 3 completed tasks** within a phase, pause and report:

```
Batch complete ([X]/[Y] tasks in Phase [N]).
Completed this batch:
- Task [A]: [one-line summary]
- Task [B]: [one-line summary]
- Task [C]: [one-line summary]

Automated verification: [run relevant tests, report PASS/FAIL]

Continue with next batch?
```

**Wait for user confirmation.** This prevents context buildup within large phases and gives the user a natural intervention point.

If the remaining tasks in the phase are 3 or fewer, skip the checkpoint and complete the phase (Step 3 handles end-of-phase reporting).

### Step 3: Phase Completion

After all tasks in a phase complete:

1. **Run automated verification** from the phase's success criteria in the plan
2. **Report results:**

```
Phase [N] tasks complete. Automated verification: [PASS/FAIL with details]
```

**If verification fails:** Stop and report. Do not proceed to review or next phase.

#### In --yolo mode:
Skip review and commit gate. Proceed directly to next phase (or plan completion).

#### In standard and deliberate modes:

Per-task reviews (spec compliance + code quality) are already complete from Step 2. Run a lightweight **cross-task integration review**, then commit gate.

**3a. Cross-Task Integration Review**

Spawn a **separate** Task agent (model: **opus**, subagent_type: **general-purpose**). This agent checks that individually-reviewed tasks work together correctly:

```
You are a staff engineer reviewing Phase [N] as a whole — checking that individually-reviewed tasks integrate correctly.

## Your Inputs
- Spec file: [spec_path]
- Plan file: [plan_path]
- Phase number: [N]

Note: Each task has already passed individual spec compliance and code quality reviews. Your job is NOT to re-review individual tasks but to check cross-task integration.

## Your Job
1. Read the spec for the phase's overall objectives
2. Read the plan's Phase [N] tasks and their "Actual Implementation" sections
3. Verify against the actual codebase:
   - Do tasks integrate correctly with each other?
   - Are there inconsistencies between tasks (naming, patterns, data flow)?
   - Does the phase as a whole satisfy its success criteria?
   - Any regressions or unintended side effects between tasks?

## Output Format
PASSED: [one-line summary]

or

ISSUES FOUND:
- [file:line] [description] [severity: blocking | warning]

## Rules
- Be terse. Only actionable findings.
- Do not modify any files. Read-only review.
- Focus on integration, not re-reviewing individual task quality.
- Check EVERY file mentioned in the tasks, not a sample.
```

**Handling review results:**

- **PASSED:** Report to user and proceed to commit gate.
- **ISSUES FOUND with blocking items:** Present issues to user. Ask: "Fix these before proceeding, or continue anyway?" Wait for user decision.
- **ISSUES FOUND with warnings only:** Report warnings and proceed to commit gate.

**3b. Update Plan File**

Update the plan file at every phase boundary (both modes):

1. **Update frontmatter counters:**
   - `tasks_complete`: current count
   - `phases_complete`: increment by 1
   - `status`: keep `in_progress` (or `complete` if last phase)

2. **Write Phase Summary** — append to the end of the phase's section in the plan:

```markdown
#### Phase [N] Summary
> Completed YYYY-MM-DD

**Branch:** `chi/<slug>-phase-<N>`
**PR:** [PR URL]
**Tasks completed:** [list with one-line outcomes]
**Deviations from plan:** [any significant changes vs. what was planned]
**Gotchas for next phase:** [anything the next session should know]
**Integration review:** [PASSED / warnings noted]
```

This ensures the plan file is always up to date — critical for deliberate mode where the next session reads it cold, and useful in standard mode for tracking.

**3c. Commit, PR, and Phase Transition**

1. **Commit** phase changes using `/commit`
2. **Create PR** for the phase using `/pr-create`. Every phase gets its own PR — this keeps reviews scoped and provides a clear audit trail per phase.
3. **Create next phase branch** (if not the last phase), stacked on current tip:

```bash
git checkout -b "chi/${SLUG}-phase-$((N+1))"
```

This ensures the new branch starts from all of phase N's work. See `stacked-branches` skill for conventions.

4. **Report:**

```
Phase [N] complete and reviewed. [PASSED / N warnings]
Committed and PR created for branch chi/<slug>-phase-<N>.
```

**In standard mode:** Proceed to next phase.

**In deliberate mode:** **STOP**. Do not continue to the next phase. Output:

```
Session ending after Phase [N]. To continue:

/continue-plan [plan_path]
```

The user starts a fresh session. The resume logic picks up at the next incomplete phase with a clean context window.

### Step 4: Plan Completion

After all phases complete:

1. Update plan frontmatter: `status: complete`
2. Update plan Changelog with completion summary
3. **Commit and PR** for the final phase (same as 3c — commit, create PR, record in Phase Summary)
4. **Collect PR data** — read each phase's Summary section from the plan file to gather branch names, PR URLs, and task outcomes
5. Present final status and Slack-ready summary:

```
## Implementation Complete

All [N] phases done. [N] tasks executed.

### Phase Breakdown

| Phase | Branch | PR | Tasks |
|-------|--------|----|-------|
| 1. [Phase name] | `chi/<slug>-phase-1` | [PR URL] | [X] tasks |
| 2. [Phase name] | `chi/<slug>-phase-2` | [PR URL] | [X] tasks |
| ... | ... | ... | ... |

### Slack Summary (copy-paste ready)

Hey team, [plan title] is ready for review — [casual 1-sentence summary of what this adds/changes and why].
1. <PR URL|PR title> — [casual 1-2 sentence explanation]
2. <PR URL|PR title> — [casual 1-2 sentence explanation]
...
Would appreciate eyes on these when you get a chance. Thanks!

Suggested next steps:
- /review-implementation [plan_path] (comprehensive final review)
```

**Generating the Slack summary:** For each phase, read the PR title from `gh pr view <URL> --json title` (or use the phase name from the plan) and write a concise explanation from the phase's tasks. Use Slack link syntax: `<URL|PR title>`. Keep the tone work-casual — friendly and concise, not formal.

---

## Resuming Implementation

This command supports resuming interrupted implementations:

1. Gets current task statuses (via TaskList or JSON files)
2. Skips tasks with status `completed`
3. Continues from first incomplete task in the earliest incomplete phase
4. **In deliberate mode:** Runs cross-phase integration check (Step 1a) when resuming at Phase 2+
5. Mode flag must be re-specified on resume (not persisted)

**For deliberate mode:** Use `/continue-plan` for resuming — it handles plan discovery, task list setup, and delegates to deliberate mode automatically.

**Manual resume (any mode):**
```bash
CLAUDE_CODE_TASK_LIST_ID=<uuid> claude
/implement-plan <plan_path> [--deliberate | --yolo]
```

---

## Error Handling

If a task fails:

1. The failure is documented in the plan's Actual Implementation section (by the task agent)
2. The task is NOT marked as completed
3. Report to user:
   - What was attempted
   - What failed (from the agent's FAILED: line)
   - Suggested remediation

The user can then:
- Fix the issue and re-run
- Modify the plan and re-run
- Skip the task (with explicit confirmation)

---

## User's Plan Path

$ARGUMENTS
