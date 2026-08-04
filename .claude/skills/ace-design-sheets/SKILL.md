---
name: ace-design-sheets
description: Writes software engineering design sheets, specs, architecture notes, and Plan-mode design text in Attempto Controlled English (ACE). Use when the user asks for a design document, design sheet, design review, architecture decision, technical spec, planning doc, or Plan-mode design work.
---

# ACE Software Engineering Design Sheets

Write every software engineering design sheet in Attempto Controlled English (ACE).

A design sheet is a decision record. Another engineer must implement the change from the sheet without a meeting.

Do not use this skill for code, commit messages, pull request bodies, or ordinary chat explanations. For teaching explanations, use the senior-engineer-explanations skill instead.

## When to write a sheet

Write a design sheet when any of these is true:

- The change crosses more than one service or store.
- The change has more than one plausible design.
- The change needs a migration, a feature flag, or a rollout plan.
- The change changes an API contract or an authz boundary.
- The reader cannot recover the decision from the code alone.

Do not write a sheet for a local bug fix with one obvious path.

## Workflow

Copy this checklist and keep it updated:

```text
Design sheet progress:
- [ ] 1. Capture problem, goals, non-goals
- [ ] 2. List constraints and current behavior
- [ ] 3. Write at least two real options with cost and risk
- [ ] 4. Record the decision and the primary reason
- [ ] 5. Expand the chosen design only
- [ ] 6. Add rollout and validation
- [ ] 7. List open questions as ACE questions
- [ ] 8. Run the sheet checklist
- [ ] 9. Ask the user to accept or revise
```

Rules for the workflow:

1. Write **Problem**, **Goals**, and **Non-goals** before any solution text.
2. Do not expand **Design** before **Decision**.
3. Do not invent a fake alternative. If only one option exists, state why the other options fail.
4. Mark uncertainty in **Open questions**. Do not hide uncertainty in prose.
5. Stop when an engineer can implement from the sheet alone.

## Required sheet structure

Use this section order. Skip a section only when it does not apply. Keep the sheet short. Prefer about one to two pages.

| # | Section | Required content |
|---|---|---|
| 1 | Title and status | Feature name; status `Draft`, `Review`, or `Accepted`; owners; date |
| 2 | Problem | User-visible failure or missing capability |
| 3 | Goals | Testable required outcomes |
| 4 | Non-goals | Explicit exclusions for this release |
| 5 | Constraints | Hard limits: latency, consistency, authz, storage, deploy path, compatibility |
| 6 | Current behavior | What the code does today; cite packages or entrypoints in backticks |
| 7 | Options | At least two options; each has behavior, cost, risk, operational impact |
| 8 | Decision | One chosen option; one primary reason; rejected options in one sentence each |
| 9 | Design | Data model, APIs, control flow, failure modes, ownership boundaries |
| 10 | Rollout and validation | Migration, flags, backfill, monitoring, proof plan |
| 11 | Open questions | Unresolved items as ACE questions |

For the full markdown skeleton, see [template.md](template.md).
For longer ACE examples and anti-patterns, see [examples.md](examples.md).

## Section guidance

### Problem

State the broken behavior or the missing capability.

Bad: The budget usage path is messy.

Good: The budget usage aggregate returns no user rows for an organization that has authz V2 enabled.

### Goals

Write goals as testable sentences.

Bad: Make usage faster and better.

Good: The aggregate returns every user that has the PermUse permission on any agent domain in the organization.

### Non-goals

Exclude work that reviewers may assume is in scope.

Example: This release does not move usage reads into ACS REST.

### Constraints

Separate hard constraints from preferences.

- A hard constraint blocks an option.
- A preference ranks options.

Example hard constraint: Check must complete without an extra service hop on the request path.

### Current behavior

Cite the real code path.

Example: `analystBudgetUsageRoster` in `graph/server/public/budget_usage.go` type-asserts `grant.Identity` to `uuid.User`.

### Options

Use a table:

| Option | Behavior | Cost | Risk | Ops impact |
|---|---|---|---|---|
| A | ... | ... | ... | ... |
| B | ... | ... | ... | ... |

Cost includes engineering time, latency, storage, and operational load.
Risk includes correctness, migration, and blast radius.

### Decision

State the choice first.

Example: The design chooses Option A because Check must avoid an extra service hop.

Then reject the other options in one sentence each.

### Design

Cover all of these:

1. **Data.** Tables, keys, null meaning, retention.
2. **API.** Inputs, outputs, authz action, error shape.
3. **Control flow.** Who calls whom; sync vs async.
4. **Failure modes.** Timeout, missing row, partial failure, fail-open vs fail-closed.
5. **Ownership.** Name systems, not people: Freya, AuraContextDB, nova-gateway, statesvc.

Do not paste large code blocks. Show signatures, schemas, and sequence steps only.

### Rollout and validation

State:

1. Schema migration order.
2. Feature flag or dark launch plan.
3. Backfill or repair plan.
4. Metrics and alerts.
5. Proof plan: unit tests, integration tests, and smoke checks.

### Open questions

Write real questions.

Bad: Authz stuff TBD.

Good: Does `AllUsersWithOrgPermission` need the same `ToV1Identity` conversion?

## Attempto Controlled English rules

ACE is a controlled subset of English. It reduces ambiguity in requirements and design text.

### Construction rules

1. Write declarative sentences. End every sentence with a period.
2. Give every sentence a subject and a verb.
3. Introduce every countable noun with a determiner: a, an, the, every, some, no, or a number.
4. Prefer the simple present tense and the third person.
5. Prefer short sentences. Split a long idea into several short sentences.
6. Build a composite sentence only with:
   - coordination: `and`, `or`
   - subordination: `if ... then`, relative clauses
   - negation: `does not`, `no`, `it is false that`
7. End a question with a question mark. Put questions only in **Open questions**, unless the user asked a question.

### Interpretation rules

1. Resolve a pronoun or a definite noun to the nearest matching antecedent.
2. If the antecedent is unclear, repeat the noun. Do not keep the pronoun.
3. Treat surface order as scope order. Place a quantifier before the content that it scopes over.
4. Prefer one meaning for one term. Define a technical term at first use.
5. If a sentence has two readings, rewrite the sentence.

### Software vocabulary policy

ACE allows content words for the domain.

- Keep standard software terms as technical names: cache, index, migration, goroutine, feature flag.
- Write identifiers and paths in backticks: `AllGrantedRoles`, `budget_usage.go`.
- Name systems consistently: Freya, AuraContextDB, nova-gateway, statesvc, ACS.
- Replace vague verbs. Replace "handle" with "retry", "reject", "log", or "forward".
- Expand an abbreviation at first use: role based access control (RBAC).

### ACE sentence patterns

Use these patterns often:

```text
Every <noun> that <clause> <verb> <object>.
If <condition>, then <system> <verb> <object>.
The <system> does not <verb> <object>.
The <system> returns <result> when <condition>.
Option A <verb> <object>. Option B <verb> <object>.
The design chooses Option A because <reason>.
```

## Depth rules for the Design section

Always include:

1. The write path and the read path.
2. The authz check and the identity that it uses.
3. The consistency model: strong, eventual, or best-effort.
4. The behavior when a dependency fails.
5. The compatibility story for old clients or old rows.

Include a sequence list when more than two components interact:

```text
1. The client calls statesvc GraphQL.
2. statesvc authorizes OrgActionInvoiceCalculate.
3. statesvc loads the policy from Freya.
4. statesvc builds the roster from authz grants.
5. statesvc joins Kubera usage and returns the aggregate.
```

Include a failure table when fail-open and fail-closed both exist:

| Failure | Behavior |
|---|---|
| Missing policy | Return an empty aggregate |
| Authz grant read fails | Return an error |
| Kubera query fails | Return an error |

## Anti-patterns

| Anti-pattern | Fix |
|---|---|
| Solution text before goals | Move goals and non-goals above options |
| One option only, with no rejection note | Add the rejected option or state why no alternative exists |
| "Maybe", "should", "somehow" | Replace with a concrete system action |
| Hidden open question in a paragraph | Move it to **Open questions** |
| Large pasted code | Replace with a signature, a schema, or a step list |
| Owner = person name | Owner = system or package |
| Ambiguous "it" / "this" | Repeat the noun |
| Preference written as a constraint | Label it as a preference |

## Output template

When you create a new sheet, start from [template.md](template.md) and fill every section that applies.

Write the sheet body in ACE. Keep tables. Tables may contain short ACE sentences.

## Final checklist

Before you present the sheet:

- [ ] Problem, goals, and non-goals appear before the solution.
- [ ] Constraints separate hard limits from preferences.
- [ ] Current behavior cites real code paths.
- [ ] At least two options include cost and risk.
- [ ] The decision names one option and one primary reason.
- [ ] Design covers data, API, flow, failure modes, and ownership.
- [ ] Rollout and validation are explicit.
- [ ] Open questions are real questions.
- [ ] Every countable noun has a determiner.
- [ ] Every sentence has a subject and a verb.
- [ ] No ambiguous pronoun remains.
- [ ] An engineer can implement from the sheet alone.
