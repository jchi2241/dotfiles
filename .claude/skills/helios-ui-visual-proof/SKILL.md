---
name: helios-ui-visual-proof
description: Use when capturing screenshots or GIFs of Helios portal UI as proof for a PR, including BEFORE/AFTER shots, mocked-frontend captures, and Cypress component test (CCT) screenshots.
---

# Helios UI visual proof

Capture screenshots a reviewer can trust. Upload them with `pr-image-upload`.

## Pick the capture path

1. **Default: the mocked frontend.** Use it for anything the mocked backend can reach.
2. **Fallback: CCT screenshots.** Use them only when the mocked app cannot reach the state.

## Mocked frontend

```bash
direnv exec <worktree> make frontend-start-mocked
```

Then drive `http://localhost:8001` with `playwright-cli` or browser tooling. For admin pages, log in with local admin credentials from the repo README when needed. If port `8001` is already owned by another worktree, ask before killing that process.

If the default mocked backend cannot produce the state, add the smallest temporary mock needed. Browser-context routing is often enough, and requests may originate from app workers:

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

Reload after installing the route, open the UI state, and take the screenshot.

## CCT screenshots

Do this after the spec already asserts the states. Do not leave screenshot calls in the branch.

`--window-size` is the Chrome window. `cy.viewport` is the CSS layout. They are not interchangeable. The default CCT viewport is 1920×1080, and headless Chrome's window is smaller, so `capture: "viewport"` saves a cropped top-left of the 1920 layout (often about 1280×577). Shrink the Cypress viewport and let the page reflow.

Always set both:

1. In the spec's render helper: `cy.viewport(1024, 768)`, then render inside `cy.then(...)`. `cy.viewport` is queued and `render()` is sync, so calling `render()` immediately still paints at 1920. Do not use `--config viewportWidth`; `component.viewportWidth` in `frontend/cypress.config.ts` wins over the CLI.
2. In `onBeforeBrowserLaunch` for Chromium: `--window-size=1060,920` (slightly larger than 1024×768) and `--force-device-scale-factor=1`. Matching window size to the viewport still clips.
3. After assertions: `cy.screenshot("descriptive-name", { capture: "viewport" })`. Prefer `viewport` over `fullPage`; `fullPage` plus Radix tooltips can hang the runner.
4. Run locally, one spec only: `direnv exec . bash -c 'cd frontend && pnpm run cct:run --spec src/pages/path/to/file.spec.tsx'`. `cct:run` supplies `NODE_ENV=test` and Chrome. No bare `--` before `--spec`. Do not send CCT screenshot jobs to CI.
5. Pixel size must be exactly 1024×768, with right-edge controls in frame. `1280×577` means clipping. Recapture with the pair above; do not bump to 1920.
6. Copy PNGs out of `frontend/cypress/screenshots/` immediately, because Cypress can clear them between runs.

## Every capture

- Save to `~/Pictures` with descriptive names, not `/tmp`: `mkdir -p "$HOME/Pictures"`.
- BEFORE/AFTER is required for visual regressions, layout changes, ordering or filtering behavior, dialogs, and empty or error states. A single AFTER is fine for purely additive UI.
- For BEFORE/AFTER, use the same route, viewport, browser session, and interaction. If you revert the fix to capture BEFORE, restore it immediately and verify the branch is clean.
- Inspect every image. If the target UI is missing, cropped, behind a loading state, dimmed, or not showing the change, retake it.
- Attach native-resolution PNGs. Do not crop and upscale (`resize`, LANCZOS, 2×). That makes PR images grainy.
- Never claim visual proof for an image you did not inspect.

## Clean up before you stop

- Remove every temporary mock, Playwright route, `cy.screenshot`, temporary `cy.viewport`, `cy.pause()`, and `--window-size` or `--force-device-scale-factor` launch arg.
- Delete local screenshot and video artifacts from the repo. Never commit the PNGs.
- Re-run the affected specs and confirm they still pass. `git status` must not include capture scaffolding.
