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
/brainstorm → /map-codebase → /create-spec → architect → /create-plan → /implement-plan → verify-helios (end to end)
 (optional)                                                                ↑ resume
                                                                     /continue-plan
```

**When to start with `/brainstorm`:** You have a fuzzy problem or feature and aren't sure where the limits are. Skip it when the task is already crisp — go straight to `/map-codebase` or `/create-spec`.

**Phase lifecycle:** A phase is a slice a user can see, shipped as several PRs (backend and frontend split). `/implement-plan` opens one draft PR per PR section as it goes, and at each phase end runs the integration lane and one live verify of the phase. Progress lives in the plan file, so `/continue-plan` resumes in any session.

**Standalone tools** (usable anytime): `/review-implementation`, `/commit`, `/handoff`, `/worktree`, `/continue-plan`

This pipeline is the feature workflow. For other kinds of work (UI change, bug fix, investigation, PR review, incident, hotfix), see the playbooks in `~/.claude/skills/chi-mode/SKILL.md`.

---

## Step 1: Scan Artifact Directories

Scan these directories for artifacts:

| Stage | Directory | Frontmatter type |
|-------|-----------|-----------------|
| Brief | `~/.claude/thoughts/briefs/` | `type: brief` |
| Map | `~/.claude/thoughts/research/` | `type: research` |
| Spec | `~/.claude/thoughts/specs/` | `type: spec` |
| Plan | `~/.claude/thoughts/plans/` | `type: plan` |

For each directory:
1. List `.md` files sorted by modification time (newest first), limit to last 30 days
2. Read the YAML frontmatter of each file to extract: title, project, status, date
3. For plans, also read: phases_total, phases_complete, prs_total, prs_complete, tasks_total, tasks_complete

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
  [~] Plan:           ~/.claude/thoughts/plans/2026-02-09_feature.md (2/5 PRs, phase 2/4)
  [ ] Implementation: In progress
  [ ] End-to-end:     Not started

  → Next: /implement-plan ~/.claude/thoughts/plans/2026-02-09_feature.md
```

Legend: `[x]` = complete, `[~]` = in progress, `[ ]` = not started

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
