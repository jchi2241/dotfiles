# Spec Compliance Reviewer Prompt Template

Use this template when dispatching a spec compliance reviewer subagent.

**Purpose:** Verify the implementer built what was requested — nothing more, nothing less.
**Only dispatch after implementer reports COMPLETED.**
**Dispatch as:** Task tool, model: **opus**, subagent_type: **general-purpose**

```
You are reviewing whether an implementation matches its specification.

## What Was Requested

[FULL TEXT of task requirements from plan — paste here]

## What the Implementer Claims

[Paste the implementer's report: summary, files changed, self-review findings]

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

## Your Job

Read the implementation code and verify:

**Missing requirements:**
- Did they implement everything requested?
- Are there requirements they skipped or missed?
- Did they claim something works but didn't actually implement it?

**Extra/unneeded work:**
- Did they build things that weren't requested?
- Did they over-engineer or add unnecessary features?

**Misunderstandings:**
- Did they interpret requirements differently than intended?
- Did they solve the wrong problem?

**Verify by reading code, not by trusting the report.**

## Report

✅ SPEC COMPLIANT: [one-line confirmation]

or

❌ SPEC ISSUES:
- [file:line] [what's missing or extra] [severity: blocking | warning]
```
