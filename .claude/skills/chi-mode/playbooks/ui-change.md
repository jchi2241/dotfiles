# UI change playbook

For a Helios portal feature or UI bug fix that ships as one frontend PR.
When the user asked for a PR ("open a PR", "take it to the finish line"), finish the PR without checkpoints. Stop only for product ambiguity, destructive actions, credentials, blocked local services, or a request to look at something together.

1. **Survey.** Read the page, route, data source, nearby specs, mocks, and product intent before editing. For a bug, reproduce it in the mocked app first (`principle-fix-root-causes`).
2. **Change.** Make the smallest product-correct change. Follow `helios-frontend-conventions`.
3. **Test.**
   - Default: add or update a focused CCT for the user-visible behavior. Read and follow the repo-local `cct-writer` skill first. Do not edit `cct-writer`.
   - Skip the CCT for portal admin-only features, very minor tweaks, copy-only changes, or setups that would be artificial. State the reason.
   - Prove red then green when practical.
4. **Check.** Run both, from the worktree root:

   ```bash
   direnv exec <worktree> bash -c 'cd frontend && pnpm run tsgo && pnpm run lint:fix && pnpm run prettier'
   direnv exec <worktree> bash -c 'cd frontend && pnpm run -r --no-bail --workspace-concurrency 1 lint'
   ```

   The recursive lint mirrors the ESLint part of the GitHub `lint-frontend` job. It catches duplicate and unused imports after review fixes. Re-run it after the final frontend commit.
5. **Visual proof.** Follow `helios-ui-visual-proof`. Clean up capture scaffolding before you commit.
6. **Ship.** `commit`, then `pr-create` with `writing-pr-descriptions`, then `pr-image-upload` for the screenshots. Do not list routine checks in the body; CI covers them.

**Done when:**

- The branch has only intended changes.
- Targeted checks and the recursive lint passed, or blockers are stated.
- Visual proof is captured, inspected, and attached when useful.
- The PR is pushed and ready for review.

If the change needs backend work, a migration, or a second PR, switch to `feature.md`.

**Reply:** the PR link, the screenshots, and anything skipped with a reason.
