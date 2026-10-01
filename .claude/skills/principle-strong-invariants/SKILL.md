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
- Derive a flag instead of storing it next to the field it depends on. `paused` is `pausedat IS NOT NULL`, not a second column to keep in sync.
- Use a dedicated type for an identifier or unit (`uuid.ObjectID`, credits as `int64` micro-units) so callers cannot mix them.
- Put `NOT NULL`, `CHECK`, and unique indexes in the migration when the rule is about stored data.
- Derive types from the schema that owns the shape: gqlgen models in Go, `__generated__` types in the frontend. Do not hand-write a parallel struct.
- Parse external input into domain types at the edge. Internal code trusts its inputs and does not re-validate.
- Keep business rules in pure functions that take domain types. The resolver, handler, or hook around them only loads, calls, and writes.
- Make an unhandled variant fail loudly. Neither Helios lint config checks switch exhaustiveness, so end a TypeScript switch with a `never` check, and give a Go enum switch a `default:` that returns an error naming the value. Adding an enum value then shows every switch that needs a case.

**Tells you missed one:**

- A `nil` check, or a `default:` that quietly returns a zero value, for a case that "can't happen".
- Optional fields that are always set in practice.
- Two fields that must be updated together.
- Casts, `any`, or `as` to make a type fit.
- A comment that says "must always be called after X" or "never null here".
- A type that copies a shape another file owns.
- A new feature that adds one more branch to an existing `if`/`else` chain. The domain wants a table, a map, or a type with variants.

**Balance:** strengthen a type only where a runtime check or a panic would otherwise be needed, then stop. The goal is that every caller handles every case it can get, not the most precise possible description of the data.

**Example:** pause state as three nullable columns plus a `CHECK` that they are all null or all set, instead of application code that checks each column.
