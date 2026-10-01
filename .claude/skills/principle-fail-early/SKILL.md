---
name: principle-fail-early
description: "Apply when writing error handling, validation, fallbacks, defaults, or retries. Prefer an explicit error at the first wrong value over silently continuing."
disable-model-invocation: true
---

# Fail Early

Return or raise an explicit error at the first point where a value is wrong. Do not continue with a guessed default.

**Why:** A silent fallback moves the failure far from its cause. The bug shows up later, in another layer, with no trace of where the bad value came from.

**How:**

- Validate at the boundary and return a clear error that names the bad input.
- Do not swallow errors. Wrap them with context and return them.
- Do not add a default value to make a missing field "work". Ask whether the field can be missing. If it cannot, error. If it can, model that in the type.
- A fallback is acceptable only when it is a product decision, written in the spec. Name it in the code.
- Log and continue only when the operation is best-effort by design, and say so at the call site.

**Tells:**

- `if err != nil { return nil }` or an empty `catch`.
- `?? defaultValue` or `|| 0` on data that should always exist.
- A retry loop around an error that will never succeed on retry.

**Exception:** fail-open is correct when the spec says so. For example, a budget check that allows the request when the usage service is down. Write the reason next to the code.
