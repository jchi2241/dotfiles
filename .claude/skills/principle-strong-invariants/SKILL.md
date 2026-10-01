---
name: principle-strong-invariants
description: "Apply when designing types, schemas, function signatures, database columns, or API shapes. Make invalid states impossible to represent instead of writing code that handles them."
disable-model-invocation: true
---

# Strong Invariants

Do not write code to handle data that should not exist. Make the type system, the schema, or a constraint reject it.

**Why:** Every branch that "handles" an impossible state is code a reader must understand and a test must cover. It also hides the bug that produced the bad state.

**How:**

- Encode the rule in the strongest layer available: a type, then a database constraint, then a check at the boundary, then a comment. Stop at the first one that holds.
- Model mutually exclusive states as one type with variants, not several optional fields. Several optional fields that are "always set together" are one struct.
- Use a dedicated type for an identifier or unit (`uuid.ObjectID`, credits as `int64` micro-units) so callers cannot mix them.
- Put `NOT NULL`, `CHECK`, and unique indexes in the migration when the rule is about stored data.
- Parse external input into domain types at the edge. Internal code trusts its inputs.

**Tells you missed one:**

- A `nil` check or `default:` branch for a case that "can't happen".
- Optional fields that are always set in practice.
- Casts, `any`, or `as` to make a type fit.
- A comment that says "must always be called after X" or "never null here".

**Example:** pause state as three nullable columns plus a `CHECK` that they are all null or all set, instead of application code that checks each column.
