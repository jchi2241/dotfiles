---
name: restack
description: Use when rebasing or restacking a chain of dependent branches or stacked PRs after a lower layer changed, cascading a fix up a stack, or resolving rebase conflicts across several branches.
---

# Restack

Cost is turns × context. Every tool call re-reads the whole conversation, so the goal is few tool calls and small outputs. A mechanical API change should cost zero turns per commit. Correctness comes first: finish with the audit below.

## Rules

- **Only move commits and adapt them.** If the request bundles new work ("while you're in pr-3, add X"), do not build it, not even as a separate commit. Finish the restack and list X as a follow-up in your report.
- **The lower layer wins.** Upper commits adapt to every change in NEW_BASE, including behavior changes and deliberate decisions (a revert, a launch, a copy or naming rule). Never revert or route around a lower-layer change. If an upper test pins the old value, update the test to the new behavior and say so.
- **Never push without explicit approval.** When approved, one `git push --atomic --force-with-lease=BRANCH:OLD_SHA ...` for all branches.
- **Batch.** Chain related commands in one Bash call. Cap output (`| tail -20`, `--stat`, `grep -n`). Never `cat` a whole file or `git log -p` a whole stack.
- **Scope builds to what exists.** Go: name packages, never the whole tree (a hook may block the `./` + `...` pattern, even inside a heredoc). TypeScript: the repo's typecheck (`tsc -p .` or `tsc --noEmit`) and test runner (`bun test`, `vitest run`, `jest`). Never install dependencies during a restack.
- **One pass.** Do not replay the cascade again for cosmetics.
- **Keep commit subjects.** If a subject is no longer accurate after adapting, say so in the report; don't reword it.

## 1. Survey (one call)

```bash
git status --short; git config rerere.enabled true
git for-each-ref --format='%(refname:short) %(objectname:short)' refs/heads   # old SHAs = undo
git log --format='%h %s%n%b' OLD_BASE..NEW_BASE                              # the lower layer's stated intent and reasons
git diff --stat OLD_BASE NEW_BASE; git diff -M OLD_BASE NEW_BASE -- <changed files>
git log --reverse --format='%h %s%n%b' --stat OLD_BASE..TOP | head -120       # what each upper commit touches, and why
git grep -n -C2 -E '<old API patterns>' TOP -- <source globs> | cut -c1-140 | head -150
```

From this, write down (in your head, not a file) three lists:
- **Mechanical changes** (signatures, types, renamed or removed symbols, moved files): the fixer handles these.
- **Behavior changes** (normalization, error wrapping, a removed helper replaced by another): `git grep` the stack for code that depends on the old behavior, including untyped string literals, dynamic keys and config values the compiler cannot check.
- **Decisions** the lower layer states a reason for (an incident, a launch, a rule). Any upper commit that touches the same value is an ambiguous conflict, even if git merges it cleanly.

GitHub stacks: add `gh api repos/O/R/stacks/N --jq '[.pull_requests[]|{n:.number,head:.head.ref,base:.base.ref}]'` to the same call. `gh stack rebase` only works for a locally tracked stack; otherwise use git.

## 2. Write the helpers, then run the cascade (two calls)

Write an idempotent `fix.py` (outside the repo) covering the first two lists, including test expectations and generators (fix the generator template, then rerun it; never hand-edit generated output). Each rule must be a no-op once applied and must skip files that don't exist yet. Write the helpers in one call (file writes only), then start the cascade in the next. Keeping writes and the history rewrite in separate calls keeps each command's effect obvious, so permission checks don't block it:

```bash
W=/path/outside/repo; mkdir -p $W
cat > $W/fix.py <<'EOF'
...
EOF
cat > $W/check.sh <<'EOF'
# typecheck/build + tests for what exists at this commit. Go: build/vet/test the listed packages.
# TypeScript: tsc -p . && (test files exist ? bun test : true)
EOF
cat > $W/step.sh <<'EOF'
set -e; python3 /path/outside/repo/fix.py; <formatter>; out=$(sh /path/outside/repo/check.sh 2>&1) || { echo "$out" | tail -20; exit 1; }
git add -A
# at a conflict stop HEAD is the previous commit: stage only, never amend it
git rev-parse -q --verify REBASE_HEAD >/dev/null && { echo "conflict stop: staged, not amended"; exit 0; }
git diff --cached --quiet || git commit -q --amend --no-edit
EOF
cat > $W/stop.sh <<'EOF'
git status --short | grep -E '^(UU|AA|DU|UD|AU|UA|DD) ' && git diff --diff-filter=U | head -80
EOF
```

```bash
# next call
git checkout -q TOP && git rebase --update-refs --onto NEW_BASE OLD_BASE TOP -x "bash $W/step.sh" 2>&1 | tail -15; sh $W/stop.sh
```

End every rebase command with `; sh $W/stop.sh`, so a stop shows its conflict hunks in the same output. `step.sh` checks and tests every commit, so a behavior break stops the rebase at the commit that caused it.

On a stop, in one call: resolve, then `bash $W/step.sh && GIT_EDITOR=true git rebase --continue 2>&1 | tail -15; sh $W/stop.sh`.

### Resolving a conflict

**Decide by intent, not by side.** For each hunk, the two inputs are the lower layer's change and the replayed commit's change. Read why each was made: the lower commit's message (from the survey) and the replayed commit's message (`git log -1 --format=%B REBASE_HEAD`). If the hunk's history is unclear, `git log --format='%h %s' -L<start>,<end>:<file> NEW_BASE` shows who last set that line and why.

- **A deliberate lower-layer decision** (a revert, a launch, a rule) keeps its value. Port only what the replayed commit set out to add (its message), on top of that value. Example: lower says "polling back to 120s (incident)", the upper commit "makes polling configurable" and still says 30s, so the result is configurable with a 120s default.
- **Both fixed the same problem differently:** keep the lower fix if it already covers the upper commit's goal, and drop the duplicate. Keep the upper commit's tests, ported.
- **The lower layer removed or launched something the upper commit builds on** (a flag, a helper): adapt the upper code to the post-launch world (no flag check). Don't re-add what was removed.
- **UU, both mechanical:** one scripted edit that keeps both.
- **AA:** union the contents. **DU/UD:** port the change to the new location (`git diff -M OLD_BASE NEW_BASE`), or, if it only touched removed code, `git rm` and `git rebase --skip`, then report the dropped commit.
- **Generated files:** take either side, fix the generator if needed, rerun it.
- **`-x` failure:** extend `fix.py`, then the same continue command. Fix the code or adapt the test to the lower layer's behavior; never delete a test or an assertion to get green.
- **Tests of removed behavior** (an assertion about a flag the lower layer deleted): replace them with assertions on the new behavior, one for one in meaning, not in count. Don't pad with filler assertions. List each replaced assertion in the report.

**When no reason is recorded.** For every value both sides set (a constant, a default, copy text, a config value), look for why the lower layer changed it: its commit message, a code comment, a linked issue, `git log -S'<value>' --format='%h %s%n%b'`. If you find no reason, the choice isn't yours to make silently. Apply the lower layer's value so the stack builds, then list it under **Needs your decision**: the file, both values, which one you applied, and the one-line change to flip it. List every such value, not just the first. Choices the code itself decides (types, a removed API, a lower fix that already covers the upper goal) don't go on that list.

## 3. Audit (one call)

```bash
git log --oneline --decorate NEW_BASE..TOP                       # every branch label on new commits
for c in $(git rev-list --reverse NEW_BASE..TOP); do git checkout -q $c && sh $W/check.sh >/dev/null 2>&1 || echo "BROKEN $c"; done
diff <(git log --format=%s OLD_BASE..OLD_TOP) <(git log --format=%s NEW_BASE..TOP)        # only the dropped commits you reported
for b in BRANCHES; do echo "$b old=$(git grep -c '<assertion pattern>' OLD_SHA_b -- <test globs> | awk -F: '{s+=$2} END{print s}') new=$(git grep -c '<assertion pattern>' $b -- <test globs> | awk -F: '{s+=$2} END{print s}')"; done
git grep -n -E '<every old literal, key or value the lower layer replaced>' TOP -- <source globs>   # must be empty
```

An assertion count that drops must be explained by the replaced assertions you listed; anything else is a weakened test. The last grep must be empty: it catches untyped leftovers (string keys, config values) that the compiler and the tests missed. Fix anything else before continuing.

## 4. Push and confirm (one call, only if approved)

`git push --atomic --force-with-lease=BRANCH:OLD_SHA ... origin BRANCHES && gh api .../stacks/N --jq ...`. Run `gh stack link` only if the parent chain changed; never `gh pr edit --base` on a stacked PR.

Report, starting with **Needs your decision** (or "none"): then the new SHA of each branch, which commits conflicted (and their type) and how they were resolved, every judgment call with its reason, dropped commits and why, behavior changes you adapted upper layers to, what you pushed, and any declined follow-ups.
