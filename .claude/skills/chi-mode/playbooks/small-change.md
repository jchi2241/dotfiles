# Small change playbook

For one PR where the approach is clear from the code.

1. **Ground.** Read the code the change touches and trace the flow end to end. Run the `how` skill when the area is unfamiliar.
2. **Pick the shape.** Climb the `ponytail` ladder. Reuse what the codebase already has.
3. **Build.**
   - Touch only lines you must touch, per Helios `agent/skills/code-review-difficulty/SKILL.md`.
   - Add only code this PR calls or tests.
   - Keep code moves in their own commit.
4. **Self-review.** Read `git diff` block by block. Justify every line that is not part of the change. Then commit with the `commit` skill.
5. **Verify and review the commit.** Run both against the same commit, in parallel.
   - Write a test that fails without the change, per `principle-test-behavior-not-implementation`.
   - Run the `verify-helios` skill on the claims the diff makes, per `principle-prove-it-works`.
   - Run `blast-radius` when the change touches a shared contract, a schema, or code that old gateways run.
   - Review with one reviewer, and handle its findings, per [`../references/review-before-pr.md`](../references/review-before-pr.md).
6. **Open the PR, when the operator asks.** Use `pr-create`.

**Escalate** to `feature.md` when the change needs a second PR, a migration, a codegate, a GraphQL change that gateways read, or a product decision.

**Reply:** what changed, the evidence, and anything skipped with a reason.
