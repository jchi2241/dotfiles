---
name: understanding-prs
description: Use when the user wants to understand a pull request or stacked PRs — what changed, why, whether it should ship, or how it fits product and strategy. Also use before a code review when the product question is still open.
---

# Understanding PRs

Decide whether the change should exist before judging the code. A clean implementation of the wrong product is still the wrong PR.

This skill does not post review comments. If the user also wants a code review, follow `reviewing-prs` after this pass.

## Gather

For each PR URL or number:

1. Metadata and diff: `gh pr view`, `gh pr diff`.
2. Stack: `baseRefName` that is not the default branch means this PR sits on another. Fetch that parent too. Evaluate the stack as a unit.
3. Stated intent: PR body, commit messages, linked ticket.
4. Product intent outside the PR: ticket description/comments, design docs, recent Slack/Glean hits. Skip keyword-only docs. An empty ticket is a signal, not a pass.

Do not treat Copilot/Bugbot summaries as the source of truth. Read the diff.

## Answer first

Lead with the verdict, then evidence:

| Question | What to decide |
|---|---|
| What | User-visible behavior, not file lists. Call out scope that snuck in beside the stated intent. |
| Why | The problem this is supposed to solve. Quote the ticket/doc if it exists; say so if you are inferring. |
| Should it | Would we do this at all? Deleting a workflow, breaking URLs, or landing users on a worse default needs an explicit product owner, not a refactor story. |
| Strategy | Does this match how the product is supposed to work, or only how the current UI is arranged? |

If those four cannot be answered, say what is missing. Do not fill gaps with the author's confidence.

## Output

Write for a reader who has not opened the PR:

1. Stack and merge order, if stacked.
2. What / why / should it / strategy, in that order.
3. What is worth doing vs what should wait.

Keep it short. No recap of every renamed symbol.

## Boundaries

- Do not approve, request changes, or comment on GitHub.
- Do not rubber-stamp "intentional" product cuts without checking there is a replacement path.
- Helios/Analyst work: use Jira and Glean when they exist. Other repos: same questions, whatever tracker the PR names.
