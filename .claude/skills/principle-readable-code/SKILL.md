---
name: principle-readable-code
description: "Apply when writing or reviewing any code. A human must be able to read, trace, and explain it without an LLM translating it."
disable-model-invocation: true
---

# Readable Code

Write code a human can read top to bottom and explain to a teammate.

**Why:** Code is read far more than written. Code only an LLM can explain cannot be reviewed, debugged at 3am, or safely changed.

**How:**

- Name things for what they are in the domain. One concept, one name, everywhere.
- Keep call chains short. If answering "what happens here" needs more than three files, flatten it.
- Collapse wrappers that have one caller and add nothing.
- Keep mutable state in the smallest scope that works.
- Prefer a table, a state machine, or a typed model over scattered conditionals.
- Match the surrounding code's style, comment density, and idioms.
- Comment only a constraint the code cannot show. Never narrate what the next line does.

**Tells:**

- A function you cannot summarize in one sentence.
- A reader must hold more than a few facts in their head to follow a block.
- Clever one-liners that need a comment to explain.
- Names like `data`, `info`, `handle`, `process`, `manager`.
