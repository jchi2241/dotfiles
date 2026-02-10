---
description: Show the workflow pipeline and detect current progress
argument-hint: [project name (optional)]
---

# Workflow Status

Show the feature development pipeline and detect where you currently are.

---

## Pipeline

The full workflow pipeline:

```
/map-codebase → /create-spec → /create-plan → /implement-plan → /commit → /pr-create
                                                    ↕ (per phase)
                                            /review-implementation
```

**Standalone tools** (usable anytime): `/review-implementation`, `/commit`, `/handoff`, `/worktree`, `/review-plan`

---

## Step 1: Scan Artifact Directories

Scan these directories for artifacts:

| Stage | Directory | Frontmatter type |
|-------|-----------|-----------------|
| Map | `~/.claude/thoughts/research/` | `type: research` |
| Spec | `~/.claude/thoughts/specs/` | `type: spec` |
| Plan | `~/.claude/thoughts/plans/` | `type: plan` |

For each directory:
1. List `.md` files sorted by modification time (newest first), limit to last 30 days
2. Read the YAML frontmatter of each file to extract: title, project, status, date
3. For plans, also read: phases_total, phases_complete, tasks_total, tasks_complete, task_list_id

If a project name is given in `$ARGUMENTS`, filter artifacts by `project:` in frontmatter.

---

## Step 2: Build Artifact Chains

Trace linked artifacts using frontmatter references:
- Spec's `research_doc:` field links to map
- Plan's `spec:` and `research_doc:` fields link to upstream artifacts

Group artifacts into chains (a chain = linked artifacts for one feature).

---

## Step 3: Display Pipeline

For each chain, show pipeline status:

```
## [Project/Feature Title]

  [x] Map:            ~/.claude/thoughts/research/2026-02-09_feature.md
  [x] Spec:           ~/.claude/thoughts/specs/2026-02-09_feature.md
  [~] Plan:           ~/.claude/thoughts/plans/2026-02-09_feature.md (3/7 tasks, phase 2/4)
  [ ] Implementation: In progress
  [ ] Review:         Not started

  → Next: /implement-plan ~/.claude/thoughts/plans/2026-02-09_feature.md
```

Legend: `[x]` = complete, `[~]` = in progress, `[ ]` = not started

For features with active task lists, check `~/.claude/tasks/<task_list_id>/` for task completion counts.

---

## Step 4: Show Unlinked Artifacts

List artifacts not part of any chain:

```
## Unlinked Artifacts
- ~/.claude/thoughts/research/2026-01-29_old-feature.md — no downstream spec or plan
```

---

## User's Filter

$ARGUMENTS
