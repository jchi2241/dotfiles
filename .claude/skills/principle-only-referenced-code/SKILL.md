---
name: principle-only-referenced-code
description: "Apply when deciding what goes into a PR or commit. Include only code that this change calls or tests. No scaffolding, unused types, or stubs for later work."
disable-model-invocation: true
---

# Only Referenced Code

A PR contains only code that the PR itself calls or tests.

**Why:** Unused code cannot be reviewed against behavior, because there is no behavior yet. It also locks in a shape before the code that needs it has been written.

**How:**

- Add a type, field, enum value, interface, or function in the PR that first calls it.
- Keep future shapes in the design document, not in code.
- Delete dead code you make dead. Do not leave it for "later cleanup".
- Do not add config, flags, or options nobody sets.

**Tells:**

- A new type with no caller in the diff.
- A `TODO` that points to a later PR.
- An enum value nothing produces or reads.
- An interface with one implementation and no test double.

**Exception:** a backend API with no caller yet is fine when it is additive and tested, and the frontend PR that calls it is next in the stack.
