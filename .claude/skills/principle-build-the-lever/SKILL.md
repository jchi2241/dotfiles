---
name: principle-build-the-lever
description: "Apply when a task needs more than a few obvious edits, or the same change across many files, rows, or repos. Build the script, codemod, or generator that does the work, so it reruns the same way and a reviewer can check it."
disable-model-invocation: true
---

# Build the Lever

When the work is not trivial, build the tool that does it instead of doing it by hand.

**Why:** A script does the work the same way every time and reruns for free. It is also one artifact a reviewer can read and rerun. Hand edits can only be re-checked by redoing them.

**How:**

- Do the first unit by hand to learn the recipe. Then build the tool, rerun it on that unit, and diff against your hand version.
- Pick the smallest lever that does the job: `gopls rename` or `gofmt -r` for a Go type or identifier change, `rg` plus a short script for a pattern edit, a generator for repeated files, a SQL query for analysis.
- Make the lever safe to rerun, per `principle-make-operations-idempotent`.
- Run a deterministic lever yourself. Do not fan out subagents to hand-apply what one script can do.
- When subagents must share the work, give them one written recipe: the steps, the check that proves a unit is done, and the files they must not touch.

**Balance:** the bar is triviality, not repetition. A one-off still earns a lever when the lever is what makes the work checkable. Build the smallest script, never a framework (`ponytail`). Commit the lever only when the user asks; otherwise keep it with the evidence and cite it in the reply.

**Tell:** you cite this principle and there is no script, codemod, or recipe file to show for it.
