# Small change playbook

For one PR where the approach is clear from the code. There is no plan file.

1. **Ground.** Read the code the change touches and trace the flow end to end. Run the `how` skill when the area is unfamiliar.
2. **Sketch.**
   - Draft the intent paragraph from the operator's words and the spec: the problem and who sees it, the outcome when the PR lands, the binding constraints and dated decisions, and what it leaves out. No symbols.
   - Climb the `ponytail` ladder and apply `principle-code-judo`. Reuse what the codebase already has.
   - Write the shape in code on the branch: types, signatures, and the call sites that change, with stub bodies. No logic.
3. **Sketch gate.** Show the operator the intent paragraph and the sketch diff. Iterate until the operator confirms the intent and approves the sketch. No body is filled in before approval.
4. **Build.** Fill in the approved sketch.
   - Touch only lines you must touch, per Helios `agent/skills/code-review-difficulty/SKILL.md`.
   - Add only code this PR calls or tests.
   - Keep code moves in their own commit.
   - A change to an approved signature or type goes back to the sketch gate.
5. **Self-review.** Read `git diff` block by block. Justify every line that is not part of the change. Then commit with the `commit` skill.
6. **Verify and review the commit.** Run both against the same commit, in parallel.
   - Write a test that fails without the change, per `principle-test-behavior-not-implementation`.
   - Run the `verify-helios` skill on the claims the diff makes, per `principle-prove-it-works`.
   - Run `blast-radius` when the change touches a shared contract, a schema, or code that old gateways run.
   - Review in three rounds and handle their findings, per [`../references/review-lanes.md`](../references/review-lanes.md).
7. **Open the PR, when the operator asks.** Use `pr-create`. Its `## Why` is the intent paragraph.

**Escalate** to `feature.md` when the change needs a second PR, a migration, a codegate, a GraphQL change that gateways read, or a product decision.

**Reply:** what changed, the evidence, and anything skipped with a reason.
