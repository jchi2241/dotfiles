# Cutting Helios work into PRs

Use this when you split a plan into PRs (`/create-plan`) and when you check a split (`/review-implementation`).
It decides what goes in each PR and in what order.
It does not cover writing the PR: title and body belong to `pr-create` and `writing-pr-descriptions`.

## Shape

- A phase is a slice a user can see. It ships as several PRs.
- One PR is one change with its own evidence. Summarize its goal in one sentence. If you can't, split or restructure it.
- Split PRs by layer. Backend and frontend go in separate PRs.
  - A backend PR lands on its own when its API is additive, not yet called, or gated.
  - A frontend PR merges after the backend it calls is merged.
- Every PR lands independently. The codebase works and ships after every merge.
- Keep PRs small: one to three plan tasks, about a day of work. A migration-only PR is fine at any size.
- Add only code the PR calls or tests. No unused types, fields, enum values, or stubs.
- Minimize review difficulty, per Helios `agent/skills/code-review-difficulty/SKILL.md`. Keep code moves and behavior-preserving refactors in their own PR, before the change that needs them.
- Order PRs so each one ends in a state you can check, and the sequence proves itself.

Anti-patterns:

- A PR adds empty files or stubs that a later PR fills in.
- A PR breaks tests or behavior, planning to fix them in the next PR.
- A frontend PR built against a backend API that has not merged.

## Jira

Several PRs share one story key. Ticket granularity rules live in the `analyst-jira-ticket` skill, under Granularity.

## Migrations

Follow Helios `migrations/README.md`.

1. Put the migration in its own PR, with no application code.
2. After review, file the apply ticket titled `apply DBNAME migration: TITLE`, with the `helios-migration-jira-ticket` skill.
3. Do not merge on approval. Merge only after the migration is applied to staging and production.
4. Application code that reads the new columns merges after the apply.
5. Make backfills, install hooks, and retries idempotent. A second run changes nothing, and a run that stops halfway finishes on a rerun.

## Mixed-version fleets

- Gateways and services deploy at different times. Assume old and new code read the same rows.
- Gate behavior a mixed fleet can see with a codegate, per Helios `agent/skills/codegate/SKILL.md`.
- Ship a safe reader change ungated. Let it reach every instance before any writer produces the new data.
- Write deploy order separately from merge order in the plan's Rollout Order. Cross-repo services (for example heliosai ACS) deploy first when Helios depends on them.

## GraphQL

- Follow Helios `agent/skills/graphql-workflow/SKILL.md`. Make additive changes, so old clients still decode the response.
- Run Helios `agent/skills/backend-lint-merge/SKILL.md` before you merge an API change.
