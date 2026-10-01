---
name: principle-refactor-over-accumulation
description: "Apply when a new requirement meets existing code, and you are about to add a conditional, wrapper, flag, or fallback to make it fit. Fix the underlying design instead."
disable-model-invocation: true
---

# Refactor Over Accumulation

When a new requirement does not fit the existing design, change the design. Do not paper over it with another branch, wrapper, or flag.

**Why:** Each patch is small, but patches compound. After a few, nobody can explain the code without reading its history.

**How:**

1. Ask what the design would look like if this requirement had existed from day one.
2. If that design is different, refactor toward it first, in its own PR or commit, with no behavior change.
3. Then add the requirement on top of the refactored code. It should now be a small change.
4. Remove the old path in the same wave. Do not keep a compatibility layer unless a mixed-version fleet needs it, and then gate it.

**Tells:**

- The same `if` appears in several places.
- A boolean parameter that changes what a function does.
- A wrapper that exists only to adjust one caller's input.
- A fix whose explanation starts with "to work around".

**Balance:** keep the refactor scoped to what the requirement needs. A broad cleanup in the same PR makes review harder (Helios `code-review-difficulty`).
