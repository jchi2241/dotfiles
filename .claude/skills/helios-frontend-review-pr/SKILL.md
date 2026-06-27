---
name: helios-frontend-review-pr
description: Use when implementing a Helios frontend feature or UI bugfix where the expected finish line is a pushed PR ready for review. Trigger for requests like "fix this frontend bug", "make this portal UI change", "open a PR", "take it to the finish line", or "add visual proof".
---

# Helios Frontend Review PR

Use this for Helios frontend work whose real finish line is a PR waiting for the user to review. Default to an autonomous path: investigate, implement, validate, capture evidence, commit, push, and create or update the PR. Stop only for product ambiguity, destructive actions, credentials, blocked local services, or when the user explicitly asks to inspect something interactively.

Read these sibling skills when needed: `helios-frontend-conventions`, `commit`, `pr-create`, `pr-image-upload`, `systematic-debugging`, and the repo-local `cct-writer` for Cypress component test conventions. Do not edit `cct-writer` as part of this workflow.

## Operating Mode

- Default to finishing the PR, not to showing checkpoints.
- Do not ask the user to manually take screenshots or edit PR text.
- Use interactive Cypress only when the user asks to see the UI or the bug requires human judgment.
- Avoid `cy.pause()` unless the user specifically asked for an interactive checkpoint; remove it before committing.
- Ask before deleting user-created files or killing unrelated long-running processes.

## Work Loop

1. Survey the page, route, data source, nearby specs, mocks, and product intent before editing.
2. Make the smallest product-correct change. Follow `helios-frontend-conventions`.
3. Choose the coverage flow:
   - **Default:** add or update a focused CCT for user-visible behavior. Read and follow the repo-local `cct-writer` skill before writing the spec.
   - **Exception:** skip the CCT for portal admin-only features, very minor tweaks, copy-only changes, or cases where the CCT setup would be artificial noise. State the reason when you skip it.
   - Prove red/green when practical. CCT mocks that support a committed regression test may stay with the test.
4. Run targeted checks:

   ```bash
   direnv exec <worktree> bash -c 'cd frontend && pnpm run tsgo && pnpm run lint:fix && pnpm run prettier'
   direnv exec <worktree> bash -c 'cd frontend && pnpm run -r --no-bail --workspace-concurrency 1 lint'
   ```

   The recursive `pnpm ... lint` command mirrors the ESLint portion of the GitHub `lint-frontend` job and catches repo-wide failures such as duplicate imports and unused imports that are easy to miss after review-fix commits.

5. Capture visual proof for user-visible changes with `make frontend-start-mocked`, not CCT screenshots unless the mocked app cannot reach the state. Save screenshots and GIFs under `~/Pictures` with descriptive names. BEFORE/AFTER is required when it makes sense: visual regressions, layout changes, ordering/filtering behavior, dialogs, empty/error states, or anything the reviewer benefits from seeing. A single AFTER is acceptable for purely additive UI or when BEFORE is indistinguishable from an error/blank state.
6. Inspect every screenshot before using it. If the target UI is missing, cropped, hidden behind a loading state, dimmed, or not showing the changed behavior, retake it.
7. Remove temporary screenshot/test-only scaffolding before committing.
8. Commit with `commit`, push safely, then create or update the PR with `pr-create`.
9. Upload visual proof with `pr-image-upload` and put it in the PR body. Keep the PR body concise: summary, short test plan, deployment plan. Do not list routine checks just to prove they ran; CI covers that.

## Visual Proof Guidance

Use the mocked frontend for user verification and screenshots:

```bash
direnv exec <worktree> make frontend-start-mocked
```

Then drive `http://localhost:8001` with Playwright or browser tooling. For admin pages, log in with local admin credentials from the repo README when needed.

If the default mocked backend cannot produce the state, add the smallest temporary mock needed for visual proof. Browser-context routing is often enough, and requests may originate from app workers:

```bash
playwright-cli run-code "async page => {
  await page.context().route('**/private?q=OperationName', route =>
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ data: { /* focused mock */ } }),
    })
  );
}"
```

Reload after installing the route, open the UI state, and take the screenshot. If port `8001` is already owned by another worktree, ask before killing that process.

Save screenshots to `~/Pictures`, not `/tmp`, so the user can find them later. Create the directory if needed:

```bash
mkdir -p "$HOME/Pictures"
playwright-cli screenshot --filename="$HOME/Pictures/<feature>-after.png"
```

For BEFORE/AFTER, prefer the same route, viewport, browser session, and UI interaction for both images. If you temporarily revert the local implementation to capture BEFORE, restore the fix immediately afterward and verify the product branch is clean.

Throw away visual-proof mocks when complete. Do not commit Playwright routes, temporary mocked-backend changes, screenshot-only data, `cy.screenshot()`, `cy.pause()`, or other visual-capture scaffolding. Use CCT screenshots only when `frontend-start-mocked` cannot reach the state; if using CCT, copy useful screenshots out of `frontend/cypress/screenshots/` immediately because Cypress can clear them between runs.

## PR Body Rules

- Explain purpose and impact, not line-by-line implementation.
- Attach verified screenshots or GIFs directly with GitHub `user-attachments` via `pr-image-upload`.
- Do not leave `[INSERT VIDEO]` or screenshot placeholders in a PR that should be review-ready.
- Do not claim visual proof if the screenshot was not inspected.
- If visual proof could not be captured, say why in the final response and leave the PR body honest.

## Finish Criteria

The task is done when:

- The branch has only intended changes.
- Targeted checks passed or blockers are clearly stated.
- The recursive frontend lint command passed after the final frontend commit.
- Visual proof is captured, inspected, and attached when useful.
- The PR is pushed and ready for user review.
