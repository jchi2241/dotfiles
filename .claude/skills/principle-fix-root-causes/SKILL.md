---
name: principle-fix-root-causes
description: "Apply when fixing a bug, a failing test, or unexpected behavior. Reproduce it end to end the way a user sees it, then fix the cause, not the symptom."
disable-model-invocation: true
---

# Fix Root Causes

Reproduce the bug the way the user hits it. Then fix the cause where every caller routes through it.

**Why:** A fix for the symptom leaves the cause in place. Sibling callers stay broken, and the next bug looks unrelated.

**How:**

1. Reproduce end to end first: the portal at `localhost:8001`, a GraphQL call, a gateway request. Not just a unit test.
2. Follow the `systematic-debugging` skill to trace back to the cause.
3. Before you edit, find every caller of the function you will change.
4. Fix it once, in the shared code.
5. Prove it with the same end-to-end reproduction, plus a test that fails without the fix.

**After two failed fixes:** write down the one assumption both fixes shared, and test that assumption before you try a third fix. Each failure under a shared assumption is evidence against it.

**Tells you fixed a symptom:**

- A `nil` check around a crash, when the value should never be `nil`.
- A `try`/`catch` that hides the error.
- A fix in one caller when three callers share the path.
- You cannot say in one sentence why the bug happened.
