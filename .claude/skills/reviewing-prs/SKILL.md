---
name: reviewing-prs
description: Use when the user asks to review a pull request, code-review a GitHub PR, or review stacked PRs. Also use when they ask to comment on or approve a PR after that review.
---

# Reviewing PRs

For reading someone else's PR. Shipping your own Helios frontend PR is `helios-frontend-review-pr`. Complexity-only review is `ponytail-review`.

## Order

1. Follow `understanding-prs`. If the change should not ship, say that and keep the code review short.
2. Review the diff. Rank findings by blocker. Stay in chat until the user asks to comment or approve.
3. If they ask to comment, follow `conventional-comments` (which follows `~/.claude/VOICE.md`).
4. Approve only when they ask. `gh pr review <n> --approve` is not implied by "review".

## Review bar

Flag only what the author would likely fix: introduced by this diff, real call path, correctness / tests / security / a meaningful maintainability hole.

Rank:

- **Blocker** — merge would ship a bug, drop coverage the PR itself broke, or leave CI red for a reason in this diff.
- **Should fix** — real defect, not merge-critical.
- **Nit** — naming, leftover copy, file still named for the old page.

Do not nit style the repo already lints. Do not re-litigate intentional product cuts already decided in the understanding pass unless the code fails to implement that cut.

CI is evidence (`gh pr checks`). A red spec that still asserts the old UI is a blocker, not a "tests need love" note.

## Stacked PRs

Comment on the PR that introduced the problem, not only the tip. A spec left stale in PR 1 is PR 1's issue even if PR 3 also fails CI.

## Chat output

1. One-line understanding verdict (or pointer if `understanding-prs` already ran).
2. Findings, blockers first, each with file/line in the diff.
3. What you did **not** comment on GitHub yet.

After comments go up, paste the GitHub discussion URLs.
