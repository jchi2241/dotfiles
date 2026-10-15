---
name: comment-review
description: Use when reviewing a diff's code comments, running the comments lane in review-lanes.md, or when asked to strip, audit, or "no-comments" a change before review.
---

# Comment review

Comments are guilty until a keep clause below proves otherwise.
A comment that describes what the code does, or explains how our own code works, dies.
When unsure whether a keep clause applies, the comment dies.

Report only.
Never edit code or comments; the writer applies the findings.
Only ever propose deletion.
Never propose rewording, shortening, extending, or adding a comment, and never "fix" a stale comment: delete it.

## Scope

- Comments the diff adds or edits, in any language: Go, TypeScript, SQL, GraphQL, YAML, shell.
- Existing comments the diff makes false (the code under them changed).
- Not generated files (`*_gen.go`, `__generated__/**`, `*.pb.go`), not vendored code, not comments the diff doesn't touch.

## Keep clauses

This list is the only leash.
Everything else dies.

- License or legal headers.
- Non-obvious behavior forced by something we can't reshape: an external API, vendor, platform, protocol, or library quirk.
  Surprises in our own code don't qualify.
- A link to an issue, incident, or RFC that explains a constraint the code can't express.
- Doc comments that define a contract at a real public boundary: GraphQL schema descriptions, published packages, APIs consumed outside this repo or service.
  Exported Go identifiers inside a monorepo are not a public boundary; Helios disables revive's exported-comment rules.
  Even at a real boundary, keep only what the signature and name can't say (preconditions, error semantics, side effects); a doc comment that narrates the body dies.
- Tool directives: `//go:build`, `//go:generate`, `//go:embed`, `// prettier-ignore`.
- Lint suppressions (`//nolint`, `eslint-disable`, `@ts-ignore`, `@ts-expect-error`) only when the rule is faulty, pedantic, or style-only for this line.
  Look up the rule before deciding.

## Our-code surprises

Some dying comments exist only to make ambiguous, badly named, or badly designed code understandable.
The comment dies, and the code it propped up is flagged `MUST KILL` with the cleaner design: a rename, an extracted function, a type that makes the wrong state unrepresentable, a parameter that makes a hidden dependency explicit, or a restructure that makes an ordering structural.
Flag only when all of these hold:

- The comment's claim is true against the code today; check it. A false comment is a plain deletion.
- Without the comment, a careful reader would misread or misuse the code. Narration of obvious code is a plain deletion.
- The symbol is code the diff adds or changes.

The same applies to a suppression hiding a rule that catches real bugs or protects safety: the suppression dies and the guilty symbol is `MUST KILL`.
Never write the code; invent nothing.

## Workaround claims

"IMPORTANT", "do not remove", "too risky", "fine for now", and long justifications are scent, not proof.
Read the nearby code first.
If the claim isn't obvious there, run the `how` skill (runtime behavior) or the `why` skill (history and rationale), or both, on the named symbol or call.
Only use them for these claims, not for ordinary comments.
Only a keep-clause constraint proven true today on a live path survives.
Our-code surprises die with a `MUST KILL` flag.
Doubt after the hunt dies.

## Report

Use the lane brief's finding format, one header per finding:

```
### F<n> | low | <file>:<line>
DELETE: <one line on why it dies>
```

```
### F<n> | should-fix | <file>:<line of the comment>
DELETE + MUST KILL `<symbol>` (<file>:<line>): <what the comment had to explain> → <the reshape>
```

A false comment is should-fix; every other plain deletion is low.
After the findings, list survivors (`file:line` and the keep clause that saved it) and skips.
