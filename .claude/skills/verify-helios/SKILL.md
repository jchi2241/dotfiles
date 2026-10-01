---
name: verify-helios
description: Drive the local Helios stack the way a user does and prove a change works end to end, with a verdict. Covers the portal against the real local backend, State SVC GraphQL, and the Analyst chat path (portal, Nova Gateway, AuraCtx, sqlbot, UMG). Use before calling a Helios or Analyst change done, to reproduce a bug, or when asked to verify, prove, or show it works.
---

# Verify Helios

Prove behavior on the real local stack, not with tests alone. Read [`features/README.md`](features/README.md), then the feature file that matches the change, and follow its recipe.

## Launch

1. Run `scripts/doctor.sh`. If it passes, skip to step 4.
2. If the k3d API server is unreachable: `direnv exec ~/projects/helios bash -c 'K3D_FIX_DNS=0 k3d cluster start helios-infra-local-dev'`. A plain `k3d cluster start` fails on the mounted `resolv.conf`.
3. If services are missing or crashlooping, follow the `babysit-init-analyst` skill, then rerun the doctor.
4. The portal must be the real-backend dev server, not `frontend-start-mocked`. If nothing serves `:8001`, start `direnv exec <worktree> make frontend-start` in the background from the worktree under test and wait for `:8001` to answer. If another worktree owns `:8001`, ask before stopping it.

Ready means `scripts/doctor.sh` prints `Stack is worth driving.`

## Doctor

`scripts/doctor.sh` is read-only. Run it before the first drive, after any drive that fails or surprises you, and after any restart. It checks the k3d API, the State SVC, Auth SVC, Nova Gateway, AuraCtx, and UMG deployments and endpoints, and which checkout serves `:8001`. `--no-portal` skips the portal checks for GraphQL-only work.

A doctor failure caused by this skill being out of date is drift: fix this skill, then rerun.

## Drive

- **Portal.** `playwright-cli` with the named session `-s=verify-helios`, so it never touches your own browser sessions. Sessions are tied to the working directory, so run every call from `~/projects/helios`. Prefer `run-code` with role and label locators (`exact: true` for short names) over snapshot refs, which change between snapshots. Take screenshots with `page.screenshot({ path })` inside `run-code`; the CLI `screenshot` command can return stale images:

  ```bash
  playwright-cli -s=verify-helios run-code "async page => { await page.getByRole('button', { name: 'Ask', exact: true }).click(); }"
  ```

  When a locator times out, run `playwright-cli -s=verify-helios snapshot --filename=/tmp/verify.yml` and read the real role and name before retrying.

  Log in as the feature file says. Save the logged-in state once with `playwright-cli -s=verify-helios state-save "$EVIDENCE/auth.json"` and reuse it with `state-load`.
- **GraphQL.** The `helios-local-gql` skill for State SVC calls with a System JWT. Use it to read back state a UI action wrote.
- **Logs per hop.** `scripts/hop-evidence.sh <session_id> "$EVIDENCE" <since>` collects Nova Gateway, AuraCtx, sqlbot, and UMG logs for the window and reports which hops saw the turn. Run it through `direnv exec ~/projects/helios`.

## Evidence

Write everything for one run under `EVIDENCE=~/Pictures/verify-helios/<YYYY-MM-DD>_<slug>/`.

- Exercise the real user path. No test-only endpoints, no setting state directly to force the result.
- Capture the action and the resulting state, not only the final screen.
- Prove side effects with a second view: reload, reopen from a list, or read back through GraphQL or logs.
- Never report an entry point as verified through a different one. Report unreachable paths with the command tried and the missing precondition.
- Inspect every screenshot before citing it.

## Verdict

For each claim the change makes:

1. Restate it so it can fail: the condition, what you observe, and the threshold.
2. When the claim is a change in behavior, capture a baseline on the base branch first, then the treatment on the branch under test, with the same recipe.
3. Return exactly one verdict: `VERIFIED`, `NOT VERIFIED`, or `INCONCLUSIVE`. A wrong surface, a skipped hop, or a missing baseline is `INCONCLUSIVE`, not a pass.

Write the claim, the steps, the artifact paths, and the verdict to `$EVIDENCE/verdict.md`.

## Cleanup

- `playwright-cli -s=verify-helios close`.
- Stop only processes this run started, by PID. Never kill by name.
- Delete chat sessions, domains, or other records the run created when the feature file says to.
- Keep `$EVIDENCE`. Cleanup never removes proof. Confirm it still exists before you report.

## Keeping it honest

When a recipe is wrong (a selector moved, a log line changed, a step is missing), fix the feature file in the same session. When the app is broken, report a product bug and leave the recipe alone. Add a feature file when you verify a feature with no file, using the shape in `features/README.md`.
