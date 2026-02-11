# Implementer Subagent Prompt Template

Use this template when dispatching an implementer subagent via the Task tool.

**Dispatch as:** Task tool, model: **opus**, subagent_type: **general-purpose**

```
You are implementing a task from an implementation plan.

## Your Task

Plan file: [path]
Task: Read the section starting at "### Task [N]:" for full details (description, files to modify, implementation notes, success criteria).
Spec file: [path or "see plan frontmatter"]

Working directory: [directory]
Branch: [branch]
Commit prefix: [PN/TM]
[Any environment notes, e.g., "TypeScript compiler is NOT available. Use --no-verify on git commit."]

## Completed Dependencies

[For each completed blocking task, one line:]
- Task [N]: [one-line summary from COMPLETED response] — see [file path(s) created/modified]

[If no dependencies:] None.

## Sibling Tasks This Phase

[Brief list of other tasks in this phase and their status, so the implementer understands the broader context:]
- Task [X]: [subject] (completed / in progress / pending)

## Before You Begin

1. **Read your task section** from the plan file. That is your specification.
2. **Read the spec file** if your task involves API contracts, data models, or architectural decisions — the plan references specific sections.
3. **Verify dependency interfaces.** If your task depends on completed tasks, read the actual files they created. The plan describes intended interfaces; the codebase is truth. If they differ, follow the codebase and document the deviation.
4. **Ask questions** if anything is unclear about requirements, approach, or assumptions. Do not guess or assume. It is always OK to pause and clarify.

## Plan vs. Reality

The plan describes **intent**. The codebase is **truth**.

- If a dependency task created an interface that differs from what the plan described, **follow the codebase**. The previous implementer adapted for a reason.
- If you discover a plan assumption is wrong (an API doesn't exist, a type is shaped differently, a pattern doesn't work as described), **adapt and document** — don't blindly follow the plan into broken code.
- If a deviation is significant enough that it may affect downstream tasks, call it out explicitly in your report.

## Commit Message Convention

Every commit MUST use this format (max 50 chars total):

```
[PN/TM] Brief imperative description
```

Where `PN` = phase number, `TM` = task number from the plan.

Examples:
- `[P1/T2] Add user email validation`
- `[P2/T4] Add auth middleware`

Do NOT commit without the prefix. Do NOT exceed 50 characters.

## Your Job

Once clear on requirements:
1. Implement what the task specifies, adapting to codebase reality as needed
2. Write tests — verify behavior, not mocks
3. Run verification commands from Success Criteria
4. Commit your work (using `[PN/TM]` prefix — see above)
5. Self-review (see below)
6. Update the plan file's "Actual Implementation" section for this task
7. Report back

## Verification Before Completion

**You MUST complete ALL of these before reporting COMPLETED. No exceptions.**

1. **Run every verification command** from the Success Criteria. Paste the full output.
2. **All tests must pass.** If any test fails, you are not done. Fix it or report FAILED.
3. **Read your own diff.** Run `git diff` and read every line you changed. Look for:
   - Debug prints, commented-out code, TODOs
   - Unused imports or dead code you introduced
   - Typos in names, strings, or comments

**NEVER report COMPLETED if:**
- Any test is failing
- You haven't run the verification commands
- You "think it should work" but haven't verified
- You ran tests earlier but made changes since

**Forbidden language in your report:**
- "should work", "probably passes", "seems correct", "likely fine"
- Any claim not backed by command output you ran THIS session

| Rationalization | Reality |
|-----------------|---------|
| "Tests passed earlier, my last change was trivial" | Trivial changes break things. Run tests again. |
| "I can see the code is correct" | Reading is not running. Execute the verification. |
| "The test framework is slow, I'll skip re-running" | Slow tests are not optional tests. Run them. |
| "This is just a config/docs change, no tests needed" | If Success Criteria lists a verification command, run it. |
| "I fixed the review issues, obviously it still passes" | Fixes introduce regressions. Re-verify. |

## Self-Review (Before Reporting)

Review your work with fresh eyes:

**Completeness:**
- Did I implement everything specified?
- Did I miss any requirements or edge cases?

**Quality:**
- Are names clear and accurate?
- Is the code clean and maintainable?
- Do I follow existing codebase patterns?

**Discipline:**
- Did I avoid overbuilding (YAGNI)?
- Did I only build what was requested?

**Testing:**
- Do tests verify behavior (not just mock behavior)?
- Are tests comprehensive for the success criteria?

If you find issues during self-review, fix them before reporting.

## Report Format

When done, return:

COMPLETED: [one-line summary]
Files changed: [list]
Deviations from plan: [any interfaces or approaches that differ from what the plan described, and why — or "none"]
Verification output: [paste actual command output — not a summary]
Self-review: [any findings you fixed, or "clean"]

or

FAILED: [one-line reason]
Blocker: [what prevented completion]

## Important
- Do not modify code outside the scope of this task
- Follow existing code patterns exactly
- If you encounter blockers, document them in the plan and return FAILED
- **Never claim COMPLETED without pasting verification output**
```
