---
name: pr-create
description: Use when the user asks to create a PR, open a pull request, or push changes for review, or when capturing Cypress CCT screenshots for a PR Test Plan.
allowed-tools: Bash(git status:*) Bash(git log:*) Bash(git branch:*) Bash(git rev-parse:*) Bash(git diff:*) Bash(gh pr:*) Bash(~/.claude/skills/pr-create/scripts/:*) Read
---

# Create Pull Request

Generate a well-structured PR from branch history and conversation context. Core principle: PR summaries explain purpose and impact, not line-by-line changes.

Your job is the PR title, body, push, and `gh pr create`. Do not change product code, commit, or amend. The only exception is temporary CCT screenshot scaffolding in **UI visual proof**, which must be fully reverted before you stop.

## Process

1. **Check state** - Run the script below to get branch info, commits, and check for uncommitted changes:
   ```
   ~/.claude/skills/pr-create/scripts/pr-state.sh
   ```
2. **If uncommitted changes exist** - Ask the user if they want to continue anyway
3. **Understand the why** - Review the conversation history to understand the purpose and motivation behind the changes
4. **Draft PR** - Combine conversation context + commits to write a meaningful title and summary
5. **Push if needed** - Use the safe push script (rejects force pushes):
   ```
   ~/.claude/skills/pr-create/scripts/safe-push.sh -u origin HEAD
   ```
6. **Create PR** - Use `gh pr create` with the drafted content and `--assignee jchi2241`

## PR Title Format

> The format below applies to the helios repository. For other repos, use a conventional short title.

`[category:type] Description`

- Categories: operator, autoscale, cellagent, frontend, backend, misc, backup, nova, hotfix
- Types: feature, fix, improvement, chore, test, ci, localdev

## PR Summary

Follow `writing-pr-descriptions` for Summary / Test Plan / Deployment Plan prose.

> The headings below apply to the helios repository. For other repos, use a simple Summary + Test Plan format.

```
## Summary
(at most 2 sentences — see writing-pr-descriptions)

## Test Plan
(this PR's targeted tests, then walkthrough / visual proof; for UI, capture via CCT then `pr-image-upload`)

## Deployment Plan
- Customer impact: Yes/No
- Rollout Plan: (feature flags, gradual rollout, etc.)
- Rollback Plan: (only if a well-defined feature flag / Codegate exists; default to N/A if only "Revert PR")
- Rollback Tested: (Yes/No if feature flag/Codegate exists, N/A if Rollback Plan is N/A)

## Subscribers
(optional - people interested but not required to review)

## JIRA Issues
(JIRA IDs, use `MCDB-NNNN #closes` in PR title for auto-close)
```

- Use `[TODO: ...]` for missing information - never fabricate

## UI visual proof (Helios CCT)

For customer-visible UI, capture screenshots from Cypress component tests rather than a hand-driven browser. Do this **after** the product spec already asserts the states; do not leave screenshot calls in the branch.

`--window-size` is the Chrome **window**. `cy.viewport` is the **CSS layout**. They are not interchangeable. Default CCT viewport is 1920×1080; headless Chrome's window is smaller. `capture: "viewport"` then saves a **cropped top-left of the 1920 layout** (often ~1280×577). Centered cards can look complete in that crop while right-edge controls (Ask, send) are clipped. Matching `--window-size` to 1920 un-crops the button but GitHub scales the image down. Shrink the Cypress viewport and let the page reflow.

**Always set both** (do not wait for a bad PNG):

1. In the spec's render helper: `cy.viewport(1024, 768)`, then render inside `cy.then(...)`. `cy.viewport` is queued; `render()` is sync — calling `render()` immediately still paints at 1920. Do **not** use `--config viewportWidth`; `component.viewportWidth` in `frontend/cypress.config.ts` wins over the CLI.
2. In `onBeforeBrowserLaunch` for Chromium: `--window-size=1060,920` (slightly **larger** than 1024×768) and `--force-device-scale-factor=1`. Matching window size to the viewport still clips.
3. After assertions: `cy.screenshot("descriptive-name", { capture: "viewport" })`. Prefer `viewport` over `fullPage` — `fullPage` plus Radix tooltips can hang the runner (`target.contains is not a function` / `scrollIntoView`).
4. Run locally (`direnv exec . bash -c 'cd frontend && NODE_ENV=test pnpm exec cypress run --component --browser chrome --spec "…"'`). Do not send CCT screenshot jobs to CI for this.
5. Inspect every PNG: pixel size must be **exactly 1024×768**, and right-edge controls must be in frame. `1280×577` means clipping — recapture with the pair above, do not bump to 1920. A centered card looking complete is not proof the shot is uncropped.
6. Attach the native PNG. Do **not** crop-and-upscale, `resize()`, LANCZOS, or otherwise invent pixels to make a small clip look larger — that is what makes PR screenshots grainy. If the subject is small, recapture at 1024×768 so the UI reflows, or attach the uncropped native shot.
7. Copy PNGs out of `frontend/cypress/screenshots/` (e.g. `~/Pictures`), upload with `pr-image-upload`, put them under Test Plan.
8. **Clean up before you stop:** remove every `cy.screenshot`, temporary `cy.viewport`, and any `window-size` / `force-device-scale-factor` launch arg. Delete local screenshot/video artifacts. Re-run the same specs and confirm they still pass. `git status` must not include screenshot scaffolding. Never commit the PNGs.

Temporary CCT instrumentation is the only code this skill may touch, and only if it is fully reverted afterward. Do not commit or amend for screenshots.

## Important

- **Do NOT make product code changes, commits, or amends** (temporary CCT screenshot calls are the exception above, and must be reverted)
- Only generate the PR summary and create the PR

## Common Mistakes

- Fabricating test results instead of using `[TODO: ...]`
- Making product code changes or amending commits (this skill is summary-only aside from reverted CCT screenshot scaffolding)
- Leaving `cy.screenshot` / extra `cy.viewport` / `--window-size` in the branch after uploading
- Setting `--window-size` without `cy.viewport` (crops the 1920 layout; does not reflow)
- Skipping `--window-size` until after a bad PNG, then "fixing" crop with `--window-size=1920,1080`
- Treating a ~1280×577 PNG as the size to match
- Cropping a screenshot and upscaling it (`resize`, LANCZOS, 2×) to fake zoom — attach native pixels or recapture
- Calling `render()` in the same tick as `cy.viewport` instead of inside `cy.then`
- Force pushing (use the safe-push script which rejects force pushes)
- Describing line-by-line changes instead of purpose and impact
