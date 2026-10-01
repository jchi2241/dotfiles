# Review before the PR

Run this after the change is implemented and before its PR opens.
`small-change.md`, `bug-fix.md` (through `small-change.md`), `ui-change.md`, and `/implement-plan` step 2g use it.

## Who reviews

- One PR from `small-change.md`, `bug-fix.md`, or `ui-change.md`: one reviewer, model role `reviewers`.
- Every PR from `feature.md` and `/implement-plan`: the model role `panel`, one reviewer per entry, in parallel.
- A reviewer is a fresh agent. Never a fork, and never the agent that wrote the code.

## The brief

Give each reviewer only the worktree path, the base ref, the commit under review, and the intent as the PR summary would state it.
Do not pass design notes, suspected risks, or a checklist. Each reviewer finds its own.

```
Read-only code review. Do not edit, commit, or push.
Worktree: <path>. Review `git diff <base>...<sha>`.
Intent: <two or three sentences>.
Read every changed file and the code that calls it.
Report what would make the change wrong, unsafe, or harder to maintain, ranked by severity, each with file:line and a concrete failure scenario.
Say plainly if nothing blocks.
```

## One commit for verify and review

- Commit before verify and review. Local commits need no operator approval. Pushing does.
- Verify and review run against the same commit, and can run in parallel.
- Record that commit's SHA in the verify verdict.

## After findings

1. Check each finding against the code. Fix the real ones. Dismiss the rest with the concrete reason.
2. Each behavior fix comes with a test that fails without it.
3. Put the fixes in a new commit, then:
   - Rerun the targeted tests.
   - If the commit touches code on a verified path, rerun verify for the claims that path carries. A commit that only changes comments, docs, or tests keeps the verdict.
   - Send the new commit's diff and the findings it addresses to fresh reviewers of the same kind.
4. Repeat until nothing blocks.

Open the PR from a commit whose verify verdict and review both stand.
