---
description: Resume implementation of an in-progress plan in a fresh session
argument-hint: [plan file path (optional)]
model: opus
---

# Continue Plan

Find an in-progress plan and resume it with `/implement-plan`. The plan file holds all progress, so a fresh session picks up where the last one stopped.

**Optional argument:** Path to plan file. If omitted, scans for in-progress plans.

---

## Step 1: Find the Plan

**If a plan path is provided in `$ARGUMENTS`:** Use it directly.

**Otherwise:**

1. Read the YAML frontmatter of each `.md` file in `~/.claude/thoughts/plans/`.
2. Keep `status: in_progress` or `pending`, newest first.
3. None: say so, and suggest `/create-plan`. One: select it. Several: list each with its PR and task progress and ask which one.

## Step 2: Resume

If every PR section already records a PR URL, report that the plan is built, and point to `feature.md` step 10 (the end-to-end `verify-helios` check). Stop.

Otherwise run `/implement-plan <plan_path>`, adding `--yolo` only when the operator asks for it. Its Step 1 finds the current PR from the plan file.

---

## User's Arguments

$ARGUMENTS
