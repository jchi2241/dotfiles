---
description: Review implementation against a plan file. Finds gaps between what was planned and what was implemented.
argument-hint: [plan file path (optional, defaults to latest in ~/.claude/plans)]
model: opus
---

# Review Plan Implementation

Verify that an implementation matches its plan. Read the plan, systematically check every requirement against the actual codebase, and report gaps.

## Review Standards

You are a staff engineer reviewing this implementation. Be scrutinous and honest. Do not soften findings, hedge with qualifiers, or omit issues to avoid friction. Do not take the user's emotions into account. Produce a cold, accurate audit — not reassurance.

Before checking individual line items, **understand the intent of the plan.** What is the plan trying to accomplish at a high level? What is the underlying goal and spirit? Hold the implementation accountable to that intent, not just the literal checklist. If the implementation technically satisfies bullet points but misses the point — or achieves the goal through a different (possibly worse) path — call it out.

Specifically watch for:
- **Shortcuts** — was work skipped, stubbed, or half-done? Were empty objects left where fields should have been removed? Were TODO comments added instead of real implementations?
- **Deviations** — any place the implementation diverges from the plan, even if the result works. The user needs to know about every deviation so they can judge whether it was acceptable. Flag it, describe the difference, and let them decide.
- **Spirit violations** — the plan may say "remove X" and the implementation removes X but leaves behind dead scaffolding, unused imports, or vestigial logic that X depended on. The letter of the plan is satisfied; the spirit is not.

---

## Step 1: Locate the Plan File

**If the user provided a path:** Use it directly. Expand `~` to the home directory.

**If no path was provided:** Find the most recently modified `.md` file in `~/.claude/plans/`:

```bash
ls -t ~/.claude/plans/*.md | head -1
```

If no plan files exist, inform the user and stop.

Read the plan file completely before proceeding.

---

## Step 2: Parse the Plan Structure

Extract from the plan:

1. **All files that should be modified** — collect every file path mentioned
2. **All specific changes per file** — what was added, removed, or modified
3. **All items that should NOT exist after implementation** — removed types, deleted code, removed exports
4. **All items that should be preserved unchanged** — explicitly marked "no changes" or "untouched"
5. **Verification commands** — any `tsc`, `grep`, test commands listed in the plan
6. **Consumer/caller updates** — components or callers that need updating due to contract changes

---

## Step 3: Verify Implementation

Launch parallel Explore agents to check all areas simultaneously. Maximize parallelism — group checks by file or theme, not sequentially.

### 3a. Verify each modified file

For every file the plan says should be modified:

- **Read the file** and confirm each specific change was made
- **Check for partial implementations** — e.g., plan says remove a field from 20 endpoints, verify all 20, not just a sample
- **Check for leftover artifacts** — empty objects `{}`, commented-out code, unused imports that should have been cleaned up

### 3b. Verify removals

For every type, export, field, or code block the plan says should be removed:

- **Grep the entire relevant codebase** for the removed identifier
- Any remaining reference is a gap (unless the plan explicitly says some references should remain)

### 3c. Verify consumer updates

For every consumer/caller file the plan mentions:

- **Read the file** and confirm the specific call-site changes
- **Check for dead params** still being passed
- **Check types** — if the contract changed, consumers should match

### 3d. Verify preserved items

For anything the plan marks as "no changes" or "already correct":

- **Read the file** and confirm it was NOT accidentally modified

### 3e. Run project-specific checks

If the plan modifies files in the **helios** project, run checks from the repo root. Choose the scope based on what was changed:

**If changes are limited to `frontend/src/`** (no changes to `fusion-design-system/` or `single-js/`):
```bash
make cp-tsc
make cp-prettier
```

**If changes also touch `fusion-design-system/` or `single-js/`:**
```bash
make frontend-tsc
make frontend-prettier
```

Report the results. Any errors or warnings are findings.

---

## Step 4: Report Results

Present a structured report:

```
## Plan Intent

[1-2 sentences: what is the plan trying to accomplish? What is the underlying goal?]

## Verification Results

### Passing
| Area | Status |
|---|---|
| [area] | [what was verified] |

### Deviations
Places where the implementation differs from the plan, regardless of whether the result works.

**[File:line] — [brief description]**
- **Plan says:** [what was specified]
- **Actual:** [what was implemented instead]
- **Assessment:** [equivalent / worse / better — but always flagged]

### Gaps Found
Places where the plan was not fully implemented.

**[File:line] — [brief description]**
- **Plan says:** [expected state]
- **Actual:** [current state]
- **Severity:** [cosmetic / functional / breaking]

### Shortcuts
Places where work appears incomplete, stubbed, or half-done.

**[File:line] — [brief description]**
- **Evidence:** [what indicates a shortcut was taken]

### Verdict
[X gaps, Y deviations, Z shortcuts found out of N verification points]
```

### Severity definitions:
- **breaking** — code won't compile, runtime error, or wrong behavior
- **functional** — works but doesn't match the plan's intent (e.g., dead code left behind)
- **cosmetic** — empty object instead of removed field, style inconsistency

---

## Rules

1. **Be exhaustive.** If the plan lists 20 endpoints to change, check all 20. Do not sample.
2. **Read before judging.** Always read the actual file content. Never assume based on grep alone.
3. **Report every deviation.** If the implementation differs from the plan in any way — different approach, different order, extra changes, missing changes, alternative solution — report it. Even if the deviation seems reasonable or equivalent, the user needs to see it. Do not silently accept "close enough."
4. **No emotional calibration.** Do not consider whether findings will be disappointing or frustrating. Report the facts.
5. **Do not modify any files.** This is a read-only review.
6. **Maximize parallelism.** Launch multiple Explore agents to check different files/areas concurrently.
7. **Include file:line references** for every gap found so the user can navigate directly.
8. **Check for shortcuts.** Look for patterns that indicate corners were cut: empty objects instead of deleted fields, `// TODO` markers, `as any` casts papering over type issues, copied code instead of the refactor the plan described, or logic that was commented out instead of removed.

---

## User's Input

$ARGUMENTS
