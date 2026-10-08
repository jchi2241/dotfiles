---
name: gh-stack
description: Use when working with GitHub stacked pull requests, the gh stack CLI, stack membership, retargeting or inserting a PR in a stack, changing a stacked PR base branch, "Cannot change the base branch because the pull request is part of a stack", or native GitHub stacks vs Graphite/git-town.
---

# GitHub stacked PRs

GitHub now owns stacked PRs natively (public preview). A **stack** is an ordered chain of PRs. Each PR's `base` is the head of the PR below it. The stack object, not `gh pr edit --base`, is what may change that chain.

Install once: `gh extension install github/gh-stack`. Run `gh stack --help` for flags. Docs: [CLI](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands), [managing](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/managing-stacked-pull-requests), [REST](https://docs.github.com/en/rest/pulls/stacks).

GraphQL can only **read** `stack` / `stackEntry`. Create, add, and unstack via REST or `gh stack`.

## Inspect first

```bash
gh api repos/OWNER/REPO/pulls/PR --jq '{n:.number,base:.base.ref,head:.head.ref,stack}'
gh api repos/OWNER/REPO/stacks/STACK
gh api "repos/OWNER/REPO/stacks?pull_request=PR"
```

`stack` is `null` for a standalone PR. `stack.position` is 1-based from the bottom. `stack.base.ref` is the stack trunk (usually `master`/`main`); `base.ref` is the parent branch.

If `.stack` is set, do not use `gh pr edit --base` or GraphQL `updatePullRequest`. That returns *Cannot change the base branch because the pull request is part of a stack*.

## Two ways to work

| Situation | Tool |
|-----------|------|
| Branches already exist / you rebased with git | `gh stack link` (no local tracking) |
| You want the CLI to own branches going forward | `gh stack init` → `add` → `submit` |

Prefer `link` when PRs already exist. Prefer `init`/`submit` when creating a new stack from this repo.

## Common workflows

### Create or rewrite a stack from existing PRs

List **bottom → top**. `link` pushes branches if needed, reuses open PRs, creates missing ones, and **corrects bases to match the chain**.

```bash
gh stack link 101 102 103
```

### Append to the top

```bash
gh stack link STACK_NUMBER 104
# or pass the full bottom-to-top list again
```

`link` is additive. Passing a stack number as the first argument **appends**. It will not insert below an existing layer.

### Insert a layer or change a parent (mid-stack)

There is no insert-below API. Unstack **open** PRs, then `link` the desired order. Merged / merging / queued PRs stay in the old stack and cannot be moved.

```bash
gh stack unstack STACK_NUMBER
gh stack link 101 102 103   # new order, bottom to top
```

Unstacking two stacks (e.g. backend + frontend) is required before joining them into one. Confirm with the user before unstacking if anything is queued or has auto-merge.

### Lower-layer change, then restack commits

With local tracking:

```bash
gh stack checkout PR_OR_BRANCH
# commit on the right layer
gh stack rebase --upstack
gh stack push          # force-with-lease; does not update PR metadata
```

### Merge

```bash
gh stack merge              # interactive
gh stack merge 102          # merge the stack up through PR 102
```

Merging a stacked PR merges **every PR from the bottom through that PR**, atomically. Do not use the legacy synchronous merge API.

## Local tracking extras

`gh stack view`, `up`/`down`/`top`/`bottom`, `checkout`, `sync`, `modify` need an adopted local stack (`gh stack init` or `gh stack checkout STACK`). `modify` is the interactive rewrite (drop/fold/reorder/insert empty branch); then `gh stack submit`.

`submit` creates/updates PRs **and** the GitHub stack. `push` only updates branches.

## Defaults

- Inspect stack membership before changing any PR base.
- Treat `gh stack link` as the default when branches and PRs already exist.
- After a git restack of already-stacked PRs, membership is often already correct; only `link`/`unstack` when the **parent chain** must change.
- Leave merged PRs in the closed historical stack; start the new open stack at the first unmerged layer.
