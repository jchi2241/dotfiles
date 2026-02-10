---
description: Create implementation plan with task breakdown
argument-hint: [feature description] [spec path]
model: opus
---

# Create Plan

Create an implementation plan and save it to `~/.claude/thoughts/plans/` as markdown.

Ensure the output directory exists: `mkdir -p ~/.claude/thoughts/plans/`

**Filename format:** `YYYY-MM-DD_<brief-one-liner-indicating-topic>.md`

---

## Task Lists

When you create tasks using the `TaskCreate` tool, Claude Code stores them in a **task list** directory:

```
~/.claude/tasks/<uuid>/
├── 1.json    # Task #1
├── 2.json    # Task #2
├── 3.json    # Task #3
└── ...
```

The UUID is automatically generated when the first task is created in a session. Each task is stored as a numbered JSON file containing the task's subject, description, status, and dependencies.

**Why this matters:** The task list ID is session-specific. If an agent in a different session needs to work on these tasks, they need to know the task list path to find and update them. Always record the task list path in the plan header after creating tasks.

**To find the current task list:** After creating tasks, check `~/.claude/tasks/` for the most recently created directory (by timestamp), or look at the task files to confirm they match your task subjects.

---

## Planning Process

### Step 1: Gather Context

**CRITICAL:** If the user references a spec document, you MUST read it first:
```
Read ~/.claude/thoughts/specs/YYYY-MM-DD_<topic>.md
```

The spec is the source of truth for WHAT to build and HOW. Your job is to sequence and decompose the spec into independently-executable tasks.

Also read any referenced documents from the spec's frontmatter:
- `research_doc:` path — for codebase context

**Do not re-evaluate the spec's technical decisions.** If the spec says "use approach X," plan for approach X. If you spot a conflict between the spec and the codebase's current state, flag it to the user — do not silently re-architect.

Record all document paths in the plan's References section.

### Step 2: Present Outline for Approval

Before writing the full plan, present a structural outline:

```
## Overview
[1-2 sentence summary]

## Implementation Phases:
1. [Phase name] - [what it accomplishes]
2. [Phase name] - [what it accomplishes]
3. [Phase name] - [what it accomplishes]

Does this phasing make sense? Should I adjust the order or granularity?
```

**Wait for user feedback on structure before proceeding.**

### Step 3: Write Full Plan

After structural approval, write the complete plan using the template below.

### Step 4: Create Tasks

After the plan is written:

**Ask for approval before creating tasks:**
```
Plan written to `~/.claude/thoughts/plans/YYYY-MM-DD_<topic>.md`.

Ready to create [N] tasks in Claude Code's task list. Proceed with task creation?
```

**Wait for user confirmation before proceeding.**

Once approved, create tasks with complete context for independent implementation:

1. Use `TaskCreate` to create each task from the plan's Task Breakdown section
   - **CRITICAL:** The task `description` MUST contain everything an agent needs to implement independently:
     ```
     Implement "Task 3: Add database migration" from the plan.

     **Plan file:** ~/.claude/thoughts/plans/2026-01-28_feature.md
     **Section:** Task 3: Add database migration (search for "### Task 3:")

     The plan is the source of truth. Read the full task section in the plan for:
     - Detailed description
     - Files to modify
     - Implementation notes
     - Success criteria
     ```
   - The description points to the plan; the plan contains all implementation details
   - This allows `/implement-plan` to spawn Task agents with full context

2. Use `TaskUpdate` to set up dependencies (`addBlockedBy` for tasks that depend on others)
3. Find the task list directory: `ls -lt ~/.claude/tasks/ | head -5`
4. Add the **Task List** path to the plan header
5. Update the Changelog to note tasks were created

---

## Plan Template

The plan MUST begin with YAML frontmatter for indexing and searchability:

```markdown
---
type: plan
title: <Descriptive Title>
project: <project name, e.g., helios, heliosai, singlestore-nexus>
area: <codebase area, e.g., frontend/intelligence, cmd/nova-gateway>
tags: [tag1, tag2, tag3]  # relevant keywords for searching
date: YYYY-MM-DD
status: pending  # draft | pending | in_progress | complete | blocked
spec: <path to spec, or null>
approach_chosen: <name of the chosen approach from spec>
research_doc: <path or null>
task_list_id: <uuid, fill in after creating tasks>
phases_total: <N>
phases_complete: 0
tasks_total: <N>
tasks_complete: 0
---

# [Feature/Task Name] Implementation Plan

## Overview

[Brief description of what we're implementing and why]

## Current State Analysis

> See spec: `<spec path>` for full technical analysis and approach decision.

### Key Constraints from Spec:
- [Constraint from spec with reference]
- [Pattern to follow from spec]
- [Architectural limit to work within]

## Desired End State

[A specification of the desired end state after this plan is complete]

### Verification Criteria:
- [How to verify the feature works correctly]
- [Expected behavior]

## What We're NOT Doing

[Explicitly list out-of-scope items to prevent scope creep]

## Implementation Approach

> Approach: [name of chosen approach from spec]
> Full details: `<spec path>`, section "Architecture"

[Brief summary of the sequencing strategy — how phases are ordered and why. This is the plan's unique contribution: not WHAT or HOW, but IN WHAT ORDER.]

---

## Task Breakdown

> **IMPORTANT:** Each task below is designed to be independently executable by an agent with fresh context. After creating tasks with `TaskCreate`, update each task's "Claude Code Task" field with its system ID (e.g., `#1`). Tasks are stored in `~/.claude/tasks/<task-list-id>/`.

### Task 1: [Descriptive Task Name]

**Claude Code Task:** _#N_ _(fill in after TaskCreate)_
**Blocked By:** None
**Phase:** 1

#### Description
[Detailed description of what needs to be done]

#### Files to Modify
- `path/to/file.ext` - [what changes]

#### Implementation Notes
[Specific guidance, code snippets, patterns to follow]

#### Success Criteria
- [ ] [Specific verifiable outcome]
- [ ] Tests pass: `<test command>`

#### Actual Implementation
> _To be filled in by the implementing agent upon completion_

```
[Agent fills this in with what was actually done, any deviations from the plan, and why]
```

---

### Task 2: [Descriptive Task Name]

**Claude Code Task:** _#N_ _(fill in after TaskCreate)_
**Blocked By:** Task 1
**Phase:** 1

[Same structure as Task 1...]

---

## Phases

### Phase 1: [Descriptive Name]

#### Overview
[What this phase accomplishes]

#### Tasks in This Phase
- Task 1: [Task name]
- Task 2: [Task name]

#### Success Criteria

**Automated Verification:**
- [ ] Migration applies cleanly: `make migrate`
- [ ] Unit tests pass: `make test-component`
- [ ] Type checking passes: `npm run typecheck`
- [ ] Linting passes: `make lint`

**Manual Verification:**
- [ ] [Feature works as expected when tested via UI]
- [ ] [No regressions in related features]

**Implementation Note:** After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to the next phase.

---

### Phase 2: [Descriptive Name]

[Similar structure...]

---

## Testing Strategy

### Unit Tests:
- [What to test]
- [Key edge cases]

### Integration Tests:
- [End-to-end scenarios]

### Manual Testing Steps:
1. [Specific step to verify feature]
2. [Another verification step]

## Performance Considerations

[Any performance implications or optimizations needed]

## Migration Notes

[If applicable, how to handle existing data/systems]

## References

- Spec: `<spec path>`
- Map: `<research path>`
- Similar implementation: `[file:line]`

---

## Changelog

| Date | Task | Claude Code Task ID | Changes |
|------|------|---------------------|---------|
| YYYY-MM-DD | - | - | Initial plan created |

```

---

## Task Completion Protocol

**CRITICAL:** When an agent works on a task, they MUST update this plan file:

### When Starting a Task:
1. Record the Claude Code task_id in the **Claude Code Task:** field
2. Add an entry to the Changelog

### When Completing a Task:
1. **Fill in "Actual Implementation" section** with:
   - What was actually done (may differ from planned)
   - Files that were modified (with line numbers)
   - Any deviations from the plan and why
   - Gotchas or learnings for subsequent tasks

2. **Update the Changelog** with completion details

3. **Update the task status** using `TaskUpdate` with `status: "completed"`
   - This updates Claude Code's task panel and persists the status

4. **Update frontmatter counters:**
   - Increment `tasks_complete`
   - Increment `phases_complete` if phase is done
   - Set `status: complete` when all tasks done

This ensures agents with fresh context picking up subsequent tasks have accurate information about the current state.

---

## Example Task Update

Before (after plan created, before tasks created):
```markdown
### Task 3: Add database migration

**Claude Code Task:** _#N_ _(fill in after TaskCreate)_
**Blocked By:** Task 2
**Phase:** 2

#### Actual Implementation
> _To be filled in by the implementing agent upon completion_
```

After tasks created with TaskCreate:
```markdown
### Task 3: Add database migration

**Claude Code Task:** #3
**Blocked By:** Task 2
**Phase:** 2

#### Actual Implementation
> _To be filled in by the implementing agent upon completion_
```

After implementation complete:
```markdown
### Task 3: Add database migration

**Claude Code Task:** #3
**Blocked By:** Task 2
**Phase:** 2

#### Actual Implementation
> Completed 2026-01-28

Added migration `20260128_add_domain_id_index.sql`:
- Created index on `sessions.domain_id` for query performance
- Migration tested locally with `make migrate`

**Deviation from plan:** Originally planned to add a composite index with `user_id`, but analysis showed single-column index is sufficient for the query patterns.

**Files modified:**
- `migrations/20260128_add_domain_id_index.sql` (new file)
- `data/conversations/filter.go:45` - Updated query to use new index hint
```

---

## After Plan is Complete

When the plan is written and tasks are created:

1. Find the task list ID: `ls -lt ~/.claude/tasks/ | head -5`
2. Update the frontmatter fields:
   - `task_list_id`: the UUID
   - `status`: `in_progress`
   - `phases_total` and `tasks_total`: actual counts

End your response with:

```
## Plan Complete

**Plan file:** `~/.claude/thoughts/plans/YYYY-MM-DD_<topic>.md`
**Task list:** `~/.claude/tasks/<uuid>/`

**Next step:** To implement the tasks from this plan, start a new session with:

CLAUDE_CODE_TASK_LIST_ID=<uuid> claude

Then run:
/implement-plan ~/.claude/thoughts/plans/YYYY-MM-DD_<topic>.md
```

This ensures the Task APIs (TaskList, TaskUpdate) can access the tasks created in this session.

---

## User's Planning Request

$ARGUMENTS
