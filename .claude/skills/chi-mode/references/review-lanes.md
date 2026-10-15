# Review lanes

Each reviewer owns one job, called a lane. It gets that job, the diff, the intent, and nothing else.
The lead decides what gets fixed by the intent: the PR's intent paragraph, which the operator confirmed at the sketch gate.
Review a PR as soon as its last commit exists, alongside its targeted tests on the same SHA. Do not wait for the push; the next PR's implementation runs alongside.
`small-change.md`, `bug-fix.md` (through `small-change.md`), `ui-change.md`, and `/implement-plan` Steps 3b, 3c, and 4 use this file.

## Lanes

| Lane | Its one job | Defined by | Model role |
|---|---|---|---|
| standards | Is this the simplest, clearest shape that does the job? Code-judo moves that delete layers, wrappers, modes, branches, and fields; names and a flow a reader understands without digging; invariants the types should hold; features the intent does not need; repo conventions, dead or duplicated code, generated files. Comments belong to the comments lane. | `principle-code-judo`, `ponytail`, `principle-refactor-over-accumulation`, `principle-readable-code`, `principle-strong-invariants`, `principle-fail-early`, `principle-only-referenced-code`; the Helios `agent/skills/` that match the diff (`go-errors`, `codegate`, `graphql-*`, frontend) | `reviewers` |
| comments | Does every comment the diff adds, edits, or makes false earn its place? Which comments hide code that should change instead? | `comment-review`, `principle-readable-code` | `comments lane` |
| tests | Does every test earn its place? Cut first, then add. Delete: tests that can't fail for a defect (including Go forms: `NoError`-only, `NotNil`/`NotEmpty`, mock-call-only, a constant compared with itself); tests of how the code works rather than what it does; a behavior already proven at another layer (keep the cheapest layer that proves it); tests whose subject the diff deleted or collapsed; any test that runs a codegate's disabled path (that path is proven once by a live rollback claim, never by a committed test; a steady-state test that skips when its gate is off is fine). Then add: behavior the diff introduces that no remaining test would catch if reverted. Each delete finding names the test that already covers it, if any. | `principle-test-behavior-not-implementation`, `principle-prove-it-works`; Helios `agent/skills/codegate/SKILL.md` when the diff adds a gate | `reviewers` |
| simplification | The standards job, run again on the fixed head as the operator's own request (see Simplification round). | the standards row's files | `reviewers` |
| correctness | Can this behave wrong at runtime: races, failure paths, fail-open versus fail-closed, contracts with callers? | `principle-fail-early`, `principle-make-operations-idempotent`, `principle-strong-invariants`; `principle-fix-root-causes` for a bug fix | `reviewers`; on a Risky PR also `contrast`, as a second agent with the same brief |
| spec (optional) | Does the diff deliver the intent and the spec's Requirements and dated Resolved decisions? Outcomes and behavior only; a different implementation shape is not a deviation. | the intent paragraph; the spec's Requirements and Resolved sections | `spec lane` |
| integration | Do the PRs since the last phase boundary fit together: branch ancestry, deploy order, gate dependencies, shapes and contracts that cross PRs? | `principle-strong-invariants`, [`helios-prs.md`](helios-prs.md), the design document | `reviewers` |

The spec lane runs on model role `spec lane`, the comments lane on model role `comments lane`, and every other lane on model role `reviewers`.

Principle files live at `~/.claude/skills/<name>/SKILL.md`. The index in `~/.claude/CLAUDE.md` stays the writer's trigger table; a lane reads only the files in its row.

No lane reads the plan.

## When

Rounds run in this order, each on the head the previous round's fix commit left:

| Round | Lanes | Then |
|---|---|---|
| 1. Shape | standards, comments, tests, in parallel on the PR's last commit | lead → one fix commit |
| 2. Simplification | simplification | lead → one fix commit |
| 3. Correctness | correctness (plus `contrast` on a Risky PR), and spec when the operator asks for it | lead → one fix commit |
| End of a phase in `/implement-plan` | integration, over that phase's PRs | lead → fix round on the PR it names |
| Push or open | none, when the pushed SHA is the reviewed SHA or round 3's fix commit | |

A PR is **Risky** when it touches locking or concurrency, auth or permissions, limits or money, fail-open versus fail-closed handling, a contract another service reads, or a backfill. When unsure, call it Risky. Say the call and its reason when you launch round 1.

A reviewer is a fresh agent. Never a fork, and never the agent that wrote the code.

## The brief

Same for every lane. Only the job line and the files it reads change. Never add suspected risks, earlier findings, or hints about where to look.

```
Read-only. Do not edit tracked files, commit, push, or check out branches.
You may build and test to prove a finding, scoped to the packages or specs the diff touches: `go build`/`go vet`/`go test -p 2` on named packages (never `./...` from a repo or module root), and one CCT spec or test file at a time with `cd frontend && pnpm run cct:run --spec <path>` (never the full frontend suite, recursive lint, or a bare `--` before `--spec`). Scratch files, such as mutation overlays, go under /tmp/review/<pr>-<lane>/, never a new worktree or a copy of the repo.
Your one job: <the lane's job, from the table>. Report nothing outside it.
Read these first, in full; they define your job: <the lane's files>. In the report's first line, list the files you read.
Worktree: <path>. Diff: `git diff <base>...<sha>` (the whole PR); read files with `git show <sha>:<path>`.
Intent, as the operator confirmed it: <the intent paragraph, verbatim>.
Do not question the intent. Challenge how the code delivers it.
Read every changed file and the code that calls it.
Write findings to /tmp/review/<pr>-<lane>[-contrast].md. Put each under a header line of exactly this form:
### F<n> | <blocker|should-fix|low|nit> | <file>:<line>
Under it: the concrete failure scenario, then the fix. Keep the detail; the report is what gets read.
End the report with one line: VERDICT: BLOCK or VERDICT: NO-BLOCK.
Reply with only the verdict line and the count of findings per severity.
```

The integration lane's brief names the PR branches and their heads instead of one diff. It may build each branch's touched packages, under the same scope rule.

Builds and tests queue machine-wide through the `heavy-slots` shims (`use heavy_slots` in the worktree's `.envrc.private`; see `~/.dotfiles/bin/heavy-slots`), and a hook refuses `go build|test|vet ./...` and `cypress run` without `--spec`.

## Simplification round

The simplification lane gets the normal brief and the standards job, plus this request, verbatim:

```
The operator asked for this round: "Focus on the `ponytail` skill (laziest correct solution, YAGNI), overengineering, collapsing unnecessary layers (`principle-refactor-over-accumulation`), the reframing that deletes rather than rearranges (`principle-code-judo`), readable names and flow (`principle-readable-code`), invariants the types should hold (`principle-strong-invariants`), defensive defaults and fallbacks that hide errors (`principle-fail-early`), code nothing calls (`principle-only-referenced-code`), and unnecessary features. Judge the flow and naming of the changed code path: could a reader tell what each stage does without digging in? Where they couldn't, propose the rename, flattening, or restructure that makes it obvious."
For a feature the intent does not need, say what it costs (code, API surface, tests) and what removing it deletes.
```

Its findings carry the operator's intent: the lead does not dismiss them as taste (question 3).

## After findings

Triage from the reports, never from a reviewer's reply or a summary of it.

1. Build the index without an agent in between:
   `rg -N --no-heading '^### F' /tmp/review/<pr>-*.md | sort -t'|' -k3`
   Sorting on `file:line` puts the same finding from two lanes next to each other.
2. Before acting on or dismissing any blocker or should-fix, read its full block in the report, then the code.
3. Run the lead judgment below on every finding. Reviewers report; the lead decides what gets fixed.
4. Write the Fix list: numbered, self-contained items a fresh fixer can apply without the reports (file, symbol, the change, and for a behavior fix the test that must fail without it).
5. One fresh fixer (model role `code workers`) applies the list as one commit and reruns the targeted tests. The lead does not edit code.

### Lead judgment

The lead is the agent that launched the lanes. It decides by the intent.

**Settled** is the confirmed intent paragraph and the spec's dated Resolved decisions. Nothing else is: not the plan's wording, not the design document's single-PR internals, not code already in the diff, not an earlier agent's notes.

Ask of each finding:

1. **Actual or hypothetical?** A real caller, input, or deploy order must reach it. Trace the call site. "If someone later refactors this" is hypothetical.
2. **Missing context?** The reviewer didn't know something settled. Cite the intent or a dated Resolved decision; nothing else counts here.
3. **Taste?** "I would do it differently" with no concrete failure. Never applies to a simplification-round finding.
4. **Premature abstraction?** Extract or share code only when it must change a second way.
5. **Inflated severity?** Adversarial reviewers fill their reports. A correctness or tests blocker that is really a style point drops to low.

The same finding from two lanes or two model families weighs more. Never dismiss a correctness or security finding just because it is inconvenient.

Put each finding in one bucket:

| Bucket | What happens |
|---|---|
| **Fix** | It makes the code serve the intent more simply or more correctly, including cutting a feature the intent does not need. Goes into the fix commit. |
| **Ask** | It would change the intent or a dated Resolved decision. `AskQuestion`, recommended option first, with what the change deletes. The answer goes into the spec's Resolved section with a date, and into the intent paragraph when it changes it. |
| **Dismiss** | It would make the code stop serving the intent, or it fails question 1, 2, 3, or 4. One-line reason naming the intent clause or the question. |

Lows and nits default to Fix: standards, simplification, and comments findings get addressed, not argued with. More than five blockers and should-fixes in Fix means the lead is not filtering hard enough; lows and nits don't count toward that. Report every bucket, Dismiss included with its reasons, so the operator can overrule.

### No reruns

Correctness runs once, last, on the code that ships, so no earlier fix escapes it.

- Round 3's fixes need no rerun.
- A behavior fix also reruns its claim's `verify-helios` lane when it touches a live-verified path.
- Anything round 3's fix cannot close goes to the operator with the reports.
- **Split first.** If the PR is over about 800 changed lines, not counting generated files and tests, stop after round 1 and propose a split. A PR that size is too big to review.

## One commit for verify and review

- Commit before verify and review. Local commits need no operator approval. Pushing does.
- Verify and review run against the same commit, and can run in parallel.
- Record that commit's SHA in the verify verdict.

Open the PR from a commit whose verify verdict and lanes all stand. In `/implement-plan`, the draft opens once targeted tests and the three rounds stand; its live claims are verified in the phase's deploy (Step 4) before it is marked ready.
