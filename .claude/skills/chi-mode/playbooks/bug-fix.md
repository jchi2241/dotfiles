# Bug fix playbook

For a bug, failing test, or unexpected behavior.
Apply `principle-fix-root-causes` throughout.

1. **Reproduce end to end.** Hit the bug the way the user does: the portal at `localhost:8001`, a GraphQL call (`helios-local-gql`), a gateway request, or the exact failing command. Capture the output. If you cannot reproduce it, say so and stop. Do not fix a guess.
2. **Find the cause.** Follow the `systematic-debugging` skill: read the full error, trace backward, state one hypothesis, test one variable.
3. **Find every caller** of the code you will change. Fix it once, where they all route through.
4. **Write the failing test first**, when a cheap test path exists (`principle-test-behavior-not-implementation`). Confirm it fails for the intended reason. If no cheap path exists, keep the end-to-end reproduction as the check and say why.
5. **Fix.** The smallest change at the cause. If the fix needs a new branch or flag to fit, stop and apply `principle-refactor-over-accumulation`.
6. **Prove it.** Re-run the test and the original end-to-end reproduction. Run `blast-radius` when the fix touches a shared contract or code that old gateways run.
7. **Ship.** For a UI bug, continue at `ui-change.md` step 4. Otherwise continue at `small-change.md` step 5.

**Reply:** the symptom, the root cause in one sentence, why it did not fail before, the fix, and the before and after evidence.
