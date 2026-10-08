# Feature playbook

For PRD-backed work that ships as more than one PR.
Steps 1 to 6 make the artifacts. Steps 7 to 10 build, check, and land them. Each step names what owns its details.

1. **Inputs.** Get the PRD link and the Jira epic. If there is no agreed PRD, stop and ask. Run `/brainstorm` only when the operator says the problem is still fuzzy.
2. **Ground.** Run the `how` skill over each subsystem the change touches, or `/map-codebase` for a large unfamiliar area. Run the `why` skill when the design changes ownership or layering.
3. **Spec.** Run `/create-spec` with the PRD as input. In addition:
   - Sync the spec to the PRD. List each gap and mismatch.
   - Ask product calls with `AskQuestion`, recommended option first. Record answers in a "Resolved" section.
   - When the PRD changes, list the new gaps before you edit the spec.
4. **Design sign-off.** Run the `architect` skill on the shapes that more than one PR uses. The output is a document. Stop for sign-off.
5. **Plan.** Run `/create-plan` with the spec and the design. It splits phases into PRs per [`../references/helios-prs.md`](../references/helios-prs.md), writes each PR's live claims, and asks the push policy (`push: drafts` or `ask`) once, so the build never waits on it.
6. **Jira.** One story per phase, or per user-visible outcome, following `analyst-jira-ticket`. Ask before you create or edit tickets.
7. **Build, per PR.** Run `/implement-plan <plan>`. For each PR, lowest first:
   - Implement each task with a fresh subagent.
   - On the PR's commit, at once: targeted tests on the touched packages, and the review lanes per [`../references/review-lanes.md`](../references/review-lanes.md).
   - The lead judgment in `review-lanes.md` decides what gets fixed. One fix commit, then rerun the targeted tests and only the lanes whose blockers or should-fixes it closes. Two rounds at most, then the operator.
   - Open a draft PR per the push policy, with its live claims marked pending.
   - On a Risky PR, also run `blast-radius` (migrations, backfills, auth, code that old gateways run) and `interrogate` (a contested design, auth, billing, or enforcement).
   - A shape that differs from the design is a deviation. Stop and report it. The same workaround in several PRs means the design is wrong. Redo step 4.
8. **Check, per phase.** `/implement-plan` runs the integration lane over the phase's PRs, then deploys the stack once and runs `verify-helios` on every live claim in the phase. Each PR gets its evidence. A failed claim is a fix round on that PR.
9. **After open.**
   - Babysit the lowest open PR in each stack (Helios `pr-babysitter`). Restack with `gh-stack`.
   - Migration PRs: follow `helios-migration-jira-ticket`.
   - Run `backend-lint-merge` before you merge an API change.
   - Track rollout steps in the plan.
10. **Done.** Run the plan's end-to-end check on the local stack with `verify-helios`, from the top of the stack. Add a feature file for each user-visible outcome that has none.

**Reply:** the artifact or PR links for the current step, the decisions made, and the next gate.
