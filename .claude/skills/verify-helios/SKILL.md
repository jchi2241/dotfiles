---
name: verify-helios
description: Drive the local Helios stack the way a user does and prove a change works end to end, with a verdict. Covers the portal against the real local backend, State SVC GraphQL, and the Analyst chat path (portal, Nova Gateway, AuraCtx, sqlbot, UMG). Use before calling a Helios or Analyst change done, to reproduce a bug, or when asked to verify, prove, or show it works.
---

# Verify Helios

Prove behavior on the real local stack, not with tests alone. The root frames the claims from the diff, fans out one lane per claim, then audits the receipts before it gives the verdict.

The claims come from the diff, not the feature files. A feature file in [`features/`](features/README.md) says how to reach and drive a surface: users, URLs, selectors, commands, and gotchas. It does not say what this change altered, and it is not a checklist. A lane that passes without observing the changed behavior proves nothing about the change.

## Launch

1. Run `scripts/doctor.sh`. If it passes, skip to step 4.
2. If the k3d API server is unreachable: `direnv exec ~/projects/helios bash -c 'K3D_FIX_DNS=0 k3d cluster start helios-infra-local-dev'`. A plain `k3d cluster start` fails on the mounted `resolv.conf`.
3. If services are missing or crashlooping, follow the `babysit-init-analyst` skill, then rerun the doctor.
4. The portal must be the real-backend dev server, not `frontend-start-mocked`. If nothing serves `:8001`, start `direnv exec <worktree> make frontend-start` in the background from the worktree under test and wait for `:8001` to answer. If another worktree owns `:8001`, ask before stopping it.

Ready means `scripts/doctor.sh` prints `Stack is worth driving.`

## Doctor

`scripts/doctor.sh` is read-only. Run it before the first drive, after any drive that fails or surprises you, and after any restart. It checks the k3d API, the State SVC, Auth SVC, Nova Gateway, AuraCtx, and UMG deployments and endpoints, and which checkout serves `:8001`. `--no-portal` skips the portal checks for GraphQL-only work.

A doctor failure caused by this skill being out of date is drift: fix this skill, then rerun.

## Frame

The root does this, before any lane starts.

1. Read `git diff <base>...<sha>` and list every behavior it adds, changes, or removes. Each one is a claim.
2. Restate each claim so it can fail: the condition, what you observe (a UI state, a GraphQL read-back, a log line, a metric), and the threshold.
3. Add a **regression** claim: the load-bearing user path, run on the base and on the head with the same recipe. If the base lacks the feature, record that and prove the end state the user waits for on the head.
4. Add a **gates** claim: the targeted tests and lint for the changed packages at the SHA.
5. Mark each claim **read-only** or **mutating**. Mutating means it changes shared stack state: codegates, an org's contract, budget rows, service images.

## Lanes

- One fresh agent per claim, model role `verify lanes`. Its brief: the claim as restated, the SHA, the feature files for the surfaces it drives, its `$EVIDENCE` subdirectory, and the report shape below. Nothing about other claims.
- The local stack is shared: one k3d cluster, one `:8001`, one Postgres. Read-only lanes run in parallel. Mutating lanes run one at a time, each restoring the state it changed before it reports. Lanes that each set up their own org or user can run in parallel.
- Each lane follows **Drive**, **Evidence**, and **Cleanup** below, and returns `VERIFIED`, `NOT VERIFIED`, or `INCONCLUSIVE` with the steps it ran, the artifact paths, and what it observed. A lane that can prove a defect lists every defect it can prove, not only the first.
- When the caller cannot spawn agents, run the lanes yourself in order, and leave the audit to the caller.

## Drive

- **Portal.** `playwright-cli` with a named session unique to the run: `S=vh-$(basename "$EVIDENCE")`, then `-s="$S"` on every call. A shared name means another agent running this skill at the same time drives the same browser: its clicks land in your recordings, and its `close` kills your session. Sessions are tied to the working directory, so run every call from `~/projects/helios`. Prefer `run-code` with role and label locators (`exact: true` for short names) over snapshot refs, which change between snapshots. Take screenshots with `page.screenshot({ path })` inside `run-code`; the CLI `screenshot` command can return stale images:

  ```bash
  playwright-cli -s="$S" run-code "async page => { await page.getByRole('button', { name: 'Ask', exact: true }).click(); }"
  ```

  When a locator times out, run `playwright-cli -s="$S" snapshot --filename=/tmp/verify.yml` and read the real role and name before retrying.

  Log in as the feature file says. Save the logged-in state once with `playwright-cli -s="$S" state-save "$EVIDENCE/auth.json"` and reuse it with `state-load`.
- **GraphQL.** The `helios-local-gql` skill for State SVC calls with a System JWT. Use it to read back state a UI action wrote.
- **Logs per hop.** `scripts/hop-evidence.sh <session_id> "$EVIDENCE" <since>` collects Nova Gateway, AuraCtx, sqlbot, and UMG logs for the window and reports which hops saw the turn. Run it through `direnv exec ~/projects/helios`.

## Evidence

Write everything for one run under `EVIDENCE=~/Pictures/verify-helios/$(date +%Y-%m-%d_%H%M)_<slug>/`. The time keeps concurrent runs of the same feature apart. Each lane writes under its own `$EVIDENCE/<claim-id>/`, and its playwright session name includes the claim ID.

- Exercise the real user path. No test-only endpoints, no setting state directly to force the result.
- Capture the action and the resulting state, not only the final screen.
- Prove side effects with a second view: reload, reopen from a list, or read back through GraphQL or logs.
- Never report an entry point as verified through a different one. Report unreachable paths with the command tried and the missing precondition.
- Inspect every screenshot before citing it.
- **Video** for UI behavior claims (flows, streaming, interactions, transitions). Static changes stay on screenshots. Wrap one user path per clip:

  ```bash
  playwright-cli -s="$S" run-code "async page => {
    await page.video().start({ size: page.viewportSize() });
    // drive the path, then take the final-state screenshot
    await page.video().stop({ path: '$EVIDENCE/<before|after>-<path>.webm' });
  }"
  ```

  WebM is the only format: no conversion step, and GitHub plays it inline. Don't use the CLI `video-start`: it downscales to 800 px wide, and text turns soft. At 1280×720 the recorder captures 25 fps during continuous motion, at roughly 40–75 KB/s, so a one-minute clip is under 5 MB.

  Start after login and setup, so the clip opens on the user's first action. Stop only after the state that proves the claim is on screen. Without `--filename` the clip lands in `.playwright-cli/` under the working directory. You can't watch the clip, so the screenshot taken just before `video-stop` stands in for its last frame: inspect that, and confirm the file is non-empty.

## Verdict

Each lane returns exactly one verdict for its claim: `VERIFIED`, `NOT VERIFIED`, or `INCONCLUSIVE`. A wrong surface, a skipped hop, a missing baseline, or a run that never observed the changed behavior is `INCONCLUSIVE`, not a pass. For a UI behavior claim with no video, the verdict is `INCONCLUSIVE`.

## Audit

The root audits the receipts before it writes the verdict. It did not drive the lanes, so it reads them cold and distrusts each lane's summary:

1. Every claim from **Frame** has a lane result. A missing or dropped lane is a gap, and a gap is not a pass.
2. Each `VERIFIED` cites artifacts that show the claim's observation at the claim's threshold. Open them. A screenshot that shows a different state, a log line from another request, or a step that set state directly to force the result makes that claim `INCONCLUSIVE`.
3. Each workaround a lane used (a stubbed response, seeded data, a skipped hop) is named in the verdict with what it leaves unproven.
4. The diff makes no behavior change that no claim covers. If it does, frame that claim and run its lane.

Write the commit SHA under test, each claim, its lane's steps and artifact paths (videos included), the audit notes, and the verdict to `$EVIDENCE/verdict.md`. The verdict holds for that commit. A later commit that touches code on a claim's path needs a new lane run for that claim, and a new audit.

## Cleanup

- `playwright-cli -s="$S" close`.
- Stop only processes this run started, by PID. Never kill by name.
- Delete chat sessions, domains, or other records the run created when the feature file says to.
- Keep `$EVIDENCE`. Cleanup never removes proof. Confirm it still exists before you report.

## Keeping it honest

When a recipe is wrong (a selector moved, a log line changed, a step is missing), fix the feature file in the same session. When the app is broken, report a product bug and leave the recipe alone. Add a feature file when you verify a feature with no file, using the shape in `features/README.md`.
