# Feature playbook

For PRD-backed work that ships as more than one PR.
It runs your existing commands in order. Each step lists only what the command does not already do.

1. **Inputs.** Get the PRD link and the Jira epic. If there is no agreed PRD, stop and ask. Run `/brainstorm` only when the operator says the problem is still fuzzy.
2. **Ground.** Run the `how` skill over each subsystem the change touches, or `/map-codebase` for a large unfamiliar area. Run the `why` skill when the design changes ownership or layering.
3. **Spec.** Run `/create-spec` with the PRD as input. In addition:
   - Sync the spec to the PRD. List each gap and mismatch.
   - Ask product calls with `AskQuestion`, recommended option first. Record answers in a "Resolved" section.
   - When the PRD changes, list the new gaps before you edit the spec.
4. **Design checkpoint.** Run the `architect` skill on the shapes that more than one PR uses. The output is a document. Stop for sign-off.
5. **Plan.** Run `/create-plan` with the spec and the design. It splits phases into PRs per [`../references/helios-prs.md`](../references/helios-prs.md). Fill in Rollout Order when deploy order differs from merge order.
6. **Jira.** One story per phase, or per user-visible outcome, following `analyst-jira-ticket`. Ask before you create or edit tickets.
7. **Build.** Run `/implement-plan --deliberate`. It opens one draft PR per PR section, through `commit`, `pr-create`, and `writing-pr-descriptions`. In addition:
   - A shape that differs from the design is a deviation. Stop and report it.
   - The same workaround in several PRs means the design is wrong. Stop and redo step 4.
   - Before each PR opens, the `panel` reviews it per [`../references/review-before-pr.md`](../references/review-before-pr.md). `/implement-plan` step 2g runs this.
8. **Extra checks for risky PRs.** These run alongside `/implement-plan`'s own reviews.
   - `blast-radius` for migrations, backfills, auth, and code that old gateways run.
   - `interrogate` when the design is contested, or the PR touches auth, billing, or enforcement.
9. **After open.**
   - Babysit the lowest open PR in each stack (Helios `pr-babysitter`). Restack with `gh-stack`.
   - File the migration apply ticket. Merge the migration only after it is applied.
   - Run `backend-lint-merge` before you merge an API change.
   - Track rollout steps in the plan.
10. **Done.** Run `/review-implementation <plan>` for a comprehensive review, then the plan's end-to-end check on the local stack with the `verify-helios` skill. Add a feature file for each user-visible outcome that has none.

**Reply:** the artifact or PR links for the current step, the decisions made, and the next gate.
