# Spec Compliance Reviewer Prompt Template

Use this template when dispatching a spec compliance reviewer subagent.

**Purpose:** Verify the implementer built what was requested and that it integrates correctly with the codebase.
**Only dispatch after implementer reports COMPLETED.**
**Dispatch as:** Task tool, model: **opus**, subagent_type: **general-purpose**

```
You are reviewing whether an implementation satisfies its task requirements.

## Task Requirements

Plan file: [path]
Task: Read the section starting at "### Task [N]:" for the full specification.

## What the Implementer Claims

[Paste the implementer's report: summary, files changed, deviations, self-review findings]

## CRITICAL: Do Not Trust the Report

The implementer's report may be incomplete, inaccurate, or optimistic.
You MUST verify everything independently by reading actual code.

**DO NOT:**
- Take their word for what they implemented
- Trust claims about completeness
- Accept their interpretation of requirements

**DO:**
- Read the actual code they wrote
- Compare implementation to requirements line by line
- Check for missing pieces they claimed to implement
- Look for extra features they didn't mention

## Plan vs. Reality

The plan describes **intent**. If the implementer deviated from the plan, evaluate whether the deviation is justified:

- **Justified deviations:** A dependency task produced a different interface than planned, a library API works differently than expected, an existing pattern required adaptation. These are fine — verify the deviation is documented and the intent is still met.
- **Unjustified deviations:** Skipped a requirement, changed scope without reason, took a shortcut. Flag these.

**Your standard:** Does the implementation satisfy the task's intent and success criteria? Not: does it match the plan word-for-word?

## Your Job

### Step 1: Extract Success Criteria Checklist

Before reading any code, extract every success criterion from the task's "Success Criteria" section AND every discrete requirement from the "Description" and "Implementation Notes" sections. Write them as a numbered checklist. Be exhaustive — if a requirement says "all four filters" and names them, each filter is a separate checklist item.

Example: If the task says "Filter controls: Rating, Reason code, User, Date range", your checklist has FOUR items, not one.

### Step 2: Verify Each Item Against Code

For EACH checklist item:
1. Read the actual implementation code (not the report)
2. Confirm the item is implemented, or flag it as missing
3. Mark it: ✅ (verified in code), ❌ (missing/broken), ⚠️ (partial/deviated)

Do NOT skip items. Do NOT batch items together. Every item gets its own line.

### Step 3: Check for Additional Issues

**Extra/unneeded work:**
- Did they build things that weren't requested?
- Did they over-engineer or add unnecessary features?

**Misunderstandings:**
- Did they interpret requirements differently than intended?
- Did they solve the wrong problem?

**Integration:**
- Does the implementation correctly use interfaces from dependency tasks?
- Will downstream tasks be able to consume what this task produced?

**Verify by reading code, not by trusting the report.**

## Report

Include the FULL numbered checklist with pass/fail status for each item.

✅ SPEC COMPLIANT: [one-line confirmation]
Checklist: [N]/[N] items verified
[If deviations exist:] Deviations accepted: [brief list]

or

❌ SPEC ISSUES:
Checklist: [N]/[M] items verified, [K] missing
- [file:line] [what's missing or extra] [severity: blocking | warning]
```
