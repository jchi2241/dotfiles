# Review lanes

Each reviewer owns one job, called a lane. It gets that job, the diff, the intent, and nothing else.
Review a PR as soon as its last commit exists, alongside its targeted tests on the same SHA. Do not wait for the push; the next PR's implementation runs alongside.
`small-change.md`, `bug-fix.md` (through `small-change.md`), `ui-change.md`, and `/implement-plan` Steps 3b, 3c, and 4 use this file.

## Lanes

| Lane | Its one job | Defined by | Model role |
|---|---|---|---|
| correctness | Can this behave wrong at runtime: races, failure paths, fail-open versus fail-closed, contracts with callers? | `principle-fail-early`, `principle-make-operations-idempotent`, `principle-strong-invariants`; `principle-fix-root-causes` for a bug fix | `reviewers`; on a Risky PR also `contrast`, as a second agent with the same brief |
| tests | Do the tests prove the behavior? Would any still pass with the change reverted? What behavior is untested? | `principle-test-behavior-not-implementation`, `principle-prove-it-works` | `reviewers` |
| standards | Does it read like this codebase: repo conventions, dead or duplicated code, comments, generated files? | `ponytail`, `principle-readable-code`, `principle-refactor-over-accumulation`, `principle-only-referenced-code`; the Helios `agent/skills/` that match the diff (`go-errors`, `codegate`, `graphql-*`, frontend) | `reviewers` |
| spec | Does the diff do what its plan section says? List every deviation. Only when a plan section exists. | the plan's `PR-N` section and the spec sections it cites | `spec lane` |
| integration | Do the PRs since the last phase boundary fit together: branch ancestry, deploy order, gate dependencies, shapes and contracts that cross PRs? | `principle-strong-invariants`, [`helios-prs.md`](helios-prs.md), the design document | `reviewers` |

The spec lane runs on model role `spec lane`; every other lane on model role `reviewers`.

Principle files live at `~/.claude/skills/<name>/SKILL.md`. The index in `~/.claude/CLAUDE.md` stays the writer's trigger table; a lane reads only the files in its row.

## When

| Moment | Lanes |
|---|---|
| A PR's last commit exists | correctness, tests, standards, and spec when a plan section exists, in parallel on that SHA |
| End of a phase in `/implement-plan` | integration, over that phase's PRs |
| Push or open | none, when the pushed SHA is the reviewed SHA |

A PR is **Risky** when it touches locking or concurrency, auth or permissions, limits or money, fail-open versus fail-closed handling, a contract another service reads, or a backfill. When unsure, call it Risky. Say the call and its reason when you launch the lanes.

A reviewer is a fresh agent. Never a fork, and never the agent that wrote the code.

## The brief

Same for every lane. Only the job line and the files it reads change. Never add suspected risks, earlier findings, or hints about where to look.

```
Read-only. Do not edit tracked files, commit, push, or check out branches.
You may build and test to prove a finding, scoped to the packages or specs the diff touches: `go build`/`go vet`/`go test -p 2` on named packages (never `./...` from a repo or module root), and one CCT spec or test file at a time with `cd frontend && pnpm run cct:run --spec <path>` (never the full frontend suite, recursive lint, or a bare `--` before `--spec`). Scratch files, such as mutation overlays, go under /tmp/review/<pr>-<lane>/, never a new worktree or a copy of the repo.
Your one job: <the lane's job, from the table>. Report nothing outside it.
Read these first; they define your job: <the lane's files>.
Worktree: <path>. Diff: `git diff <base>...<sha>`; read files with `git show <sha>:<path>`.
Intent: <two or three sentences, as the PR summary would state it>.
Read every changed file and the code that calls it.
Write findings to /tmp/review/<pr>-<lane>[-contrast].md. Put each under a header line of exactly this form:
### F<n> | <blocker|should-fix|low|nit> | <file>:<line>
Under it: the concrete failure scenario, then the fix. Keep the detail; the report is what gets read.
End the report with one line: VERDICT: BLOCK or VERDICT: NO-BLOCK.
Reply with only the verdict line and the count of findings per severity.
```

The integration lane's brief names the PR branches and their heads instead of one diff. It may build each branch's touched packages, under the same scope rule.

Builds and tests queue machine-wide through the `heavy-slots` shims (`use heavy_slots` in the worktree's `.envrc.private`; see `~/.dotfiles/bin/heavy-slots`), and a hook refuses `go build|test|vet ./...` and `cypress run` without `--spec`.

## After findings

Triage from the reports, never from a reviewer's reply or a summary of it.

1. Build the index without an agent in between:
   `rg -N --no-heading '^### F' /tmp/review/<pr>-*.md | sort -t'|' -k3`
   Sorting on `file:line` puts the same finding from two lanes next to each other.
2. Before acting on or dismissing any blocker or should-fix, read its full block in the report, then the code. A low or nit can be dismissed from its index line.
3. Fix the real ones. Dismiss the rest with the concrete reason.
4. Each behavior fix comes with a test that fails without it.
5. Put the fixes in a new commit, rerun the targeted tests, and rerun only the lanes the fix touches, on the fix commit's diff:

   | The fix changes | Rerun |
   |---|---|
   | behavior | correctness and tests |
   | tests only | tests |
   | comments, names, or structure | standards |
   | code on a live-verified path | that claim's `verify-helios` lane |

   A rerun is a fresh agent with the same brief. Each finding is fixed and proven by its test; the rerun does not hear about it.
6. Repeat until no lane blocks.

## One commit for verify and review

- Commit before verify and review. Local commits need no operator approval. Pushing does.
- Verify and review run against the same commit, and can run in parallel.
- Record that commit's SHA in the verify verdict.

Open the PR from a commit whose verify verdict and lanes all stand. In `/implement-plan`, the draft opens once targeted tests and lanes stand; its live claims are verified in the phase's deploy (Step 4) before it is marked ready.
