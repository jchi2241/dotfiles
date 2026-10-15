---
name: principle-code-judo
description: "Apply when reviewing or shaping a diff's structure, before accepting working code as done. Look for the reframing that makes whole layers, branches, modes, or features disappear, not a local cleanup."
disable-model-invocation: true
---

# Code Judo

Working code is not the bar. Look for the move that uses the existing architecture better and makes the change dramatically smaller: whole branches, helpers, modes, fields, or features disappear instead of being rearranged.

**Why:** Reviews that stop at "rename this" leave the incidental complexity in place, and each later change pays for it. A deletion is the only cleanup that never needs maintaining.

**How:**

1. Name what the change must do, in one sentence from the intent. Everything that sentence does not need is a candidate to delete, including whole features.
2. Ask what disappears if you reframe: a second path that duplicates the first, a mode that a parameter already covers, a result field nobody reads, a report the caller can compute.
3. Prefer the move that deletes over the one that moves code around. Spreading the same complexity across new files is not a simplification.
4. Put logic in its canonical layer and reuse the helper that already exists, instead of adding a parallel one.
5. Prefer direct, boring code: no identity wrappers, pass-through helpers, or generic mechanisms that hide one data-shape assumption.

**Presumptive blockers** (each needs a stated reason to keep):

- Incidental complexity that a reframing would delete.
- A feature, mode, or option the intent does not ask for.
- Ad-hoc branches or feature checks scattered into an existing flow.
- A wrapper, abstraction, or mirror type that adds a layer without buying clarity.
- A file pushed past about 1,000 lines.

**Tone:** direct. When the real issue is structural, say so; don't soften it into a naming nit.

**Balance:** a cut that changes the intent, or a dated operator decision, is the operator's call. Report it with what it deletes, and let the lead ask.

Adapted from pstack `interrogate` `code-quality-review.md`; maintained here, not synced.
