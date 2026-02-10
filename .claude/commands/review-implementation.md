---
description: Review implementation against spec and plan - phase gate or comprehensive
argument-hint: [plan file path] OR [phase N] [plan file path]
model: opus
---

# Review Implementation

Verify that an implementation matches its spec and plan. Runs as either a scoped phase gate or a comprehensive standalone review.

---

## Review Standards

You are a staff engineer reviewing this implementation. Be scrutinous and honest. Do not soften findings, hedge with qualifiers, or omit issues. Produce a cold, accurate audit — not reassurance.

**You are reviewing with fresh context.** You have the spec, the plan, and the codebase. You have NO implementation narrative or conversation history.

Before checking individual items, **understand the intent.** What is the spec trying to accomplish at a high level? Hold the implementation accountable to that intent, not just a literal checklist.

Watch for:
- **Shortcuts** — stubs, TODOs, `as any` casts, empty objects, commented-out code instead of deleted code
- **Deviations** — any divergence from spec or plan, even if the result works
- **Spirit violations** — letter of the plan satisfied but intent missed (dead scaffolding, unused imports, vestigial logic)

---

## Step 1: Parse Arguments and Determine Mode

Parse `$ARGUMENTS`:
- If it matches `phase <N> <path>`: **Phase Gate Mode** for phase N
- If it's just a path: **Comprehensive Mode** reviewing the full plan
- If no path: find the most recently modified `.md` in `~/.claude/thoughts/plans/`:
  ```bash
  ls -t ~/.claude/thoughts/plans/*.md | head -1
  ```

---

## Step 2: Load Context

Read these documents (and ONLY these):

1. **Plan file** at the provided path
2. **Spec file** from the plan's `spec:` frontmatter field

If the spec is missing, warn but continue (review against plan only).

---

## Step 3: Scope the Review

### Phase Gate Mode

Review ONLY the tasks in Phase [N]:
- Read each task's "Actual Implementation" section
- Verify each task's success criteria against the codebase
- Check spec alignment for the phase's scope
- Focus on blocking issues — this is a lightweight check

### Comprehensive Mode

Review ALL tasks across ALL phases:
- Full verification of every task's success criteria
- Full spec alignment (intent, not just checklist)
- Shortcuts, dead code, spirit violations
- Cross-phase consistency (do later phases break earlier work?)

---

## Step 4: Verify

For each task/phase in scope, launch parallel Explore agents to check concurrently:

### 4a. Spec Intent Check
- Does the implementation match the spec's chosen approach?
- Are data models correct per the spec?
- Do API contracts match the spec?
- Is the migration strategy followed?

### 4b. Plan Checklist Check
- Is each task's success criteria satisfied?
- Are "Files to Modify" actually modified?
- Do "Actual Implementation" sections match reality?

### 4c. Removal Verification
For every type, export, field, or code block the plan says should be removed:
- Grep the relevant codebase for the removed identifier
- Any remaining reference is a gap

### 4d. Quality Check
- Stubs, TODOs, `as any` casts, empty objects where fields should be removed
- Unused imports, dead code, vestigial logic
- Code that was commented out instead of deleted

---

## Step 5: Run Automated Checks

Run verification commands from the plan's success criteria sections. Report results.

---

## Step 6: Report Results

### Phase Gate Mode Output:

```
## Phase [N] Review

**Verdict:** PASS / FAIL

[If FAIL:]
### Blocking Issues
- [file:line] — [description]. Fix before proceeding.

[If warnings:]
### Warnings
- [file:line] — [description]. Non-blocking.
```

### Comprehensive Mode Output:

```
## Implementation Review: [Plan Title]

### Spec Alignment
| Spec Section | Status | Notes |
|-------------|--------|-------|
| [section] | [match/deviation/gap] | [details] |

### Task Verification
| Task | Status | Issues |
|------|--------|--------|
| Task 1: [name] | [pass/fail] | [details] |

### Deviations
**[file:line] — [description]**
- **Spec/Plan says:** [expected]
- **Actual:** [what exists]
- **Assessment:** [equivalent / worse / better]

### Gaps Found
**[file:line] — [description]**
- **Expected:** [what should exist]
- **Actual:** [what exists]
- **Severity:** [cosmetic / functional / breaking]

### Shortcuts
**[file:line] — [description]**
- **Evidence:** [what indicates a shortcut]

### Verdict
[X gaps, Y deviations, Z shortcuts out of N verification points]
**Recommendation:** [proceed / fix and re-review]
```

### Severity definitions:
- **breaking** — won't compile, runtime error, or wrong behavior
- **functional** — works but doesn't match spec intent
- **cosmetic** — style inconsistency, empty object instead of removed field

---

## Rules

1. **Be exhaustive.** If the plan lists 20 changes, check all 20.
2. **Read before judging.** Always read actual file content.
3. **Report every deviation.** Even if it seems reasonable.
4. **No emotional calibration.** Report facts.
5. **Do not modify any files.** Read-only review.
6. **Maximize parallelism.** Launch multiple Explore agents concurrently.
7. **Include file:line references** for every finding.
8. **Check spec AND plan.** Spec for intent, plan for checklist.

---

## User's Input

$ARGUMENTS
