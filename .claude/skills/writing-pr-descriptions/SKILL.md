---
name: writing-pr-descriptions
description: Use when writing, drafting, or updating a GitHub pull request description, summary, test plan, or deployment plan — including Helios PR bodies, stacked-PR summaries, and requests like "update the PR summary", "rewrite the PR description", or "draft the PR body".
---

# Writing PR descriptions

Give the reviewer plain-English context for what they are about to read. The body is not a changelog, a stack map, or a record of how the PR got here.

GitHub PR bodies are formal writing (sentence case). Slack and review comments stay on `VOICE.md`.

Helios section headings and title lint stay in `pr-create`. This skill is the prose inside those sections.

## Before writing

- Updating an existing PR: `gh pr view` first. Change only the sections asked. If the user already edited the body, keep their wording.
- Rewriting descriptions they did not ask to apply yet: draft in chat and wait.

## Summary

At most two sentences. Prefer one. What this PR does; a short *why* only if the what is confusing without it.

Write the product as it exists on this branch vs its base. Name user-visible things (tab, cards, flyout, banner). Name an implementation artifact only when that artifact *is* the review surface (a new data layer, a new endpoint).

```
Adds an empty employee-only Budget tab on the Billing page, plus the GraphQL data layer that loads Analyst credit budgets.
Adds Monthly Budget and Monthly Usage cards so employees can see the org credit limit and how much has been used this month.
Analyst chat shows a dismissible warning near the monthly credit limit, and a blocking banner that disables the input once a hard limit is hit.
```

Stay out of the summary:

- Other PRs, stack position, "lands in #N", "vertical slice", "already reviewed", resplit/rebase history
- Incomplete-slice narration ("with only this change the tab shows loading states")
- Architecture asides the reviewer will see in the diff (fail-open, gateway status, query params)
- File/function/field lists

If this slice is incomplete, say the product state in one word ("empty tab"), not the stack plan.

## Test Plan

What *this* PR covers, then where to watch the feature. Not that CI ran.

- One short line for targeted tests (CCTs, unit tests) and what they cover
- Do not list mock URLs, query flags, or spec filenames unless that is the only way to exercise it
- Do not list `tsc` / lint / prettier / knip

Stacked PRs: embed the walkthrough only on the PR that owns the finished flow. Earlier PRs point at that number. Referencing the PR is enough; do not re-embed the same video.

```
- CCTs cover tab visibility (hidden for non-employees and orgs without Analyst).
- Manual e2e of the finished Budget tab is recorded on #26590.
```

On the owning PR, embed the attachment:

```
CCTs cover Configure/Manage save paths. Manual e2e:

[Screencast from 08-12-2026 07:33:13 PM.webm](https://github.com/user-attachments/assets/…)
```

No `[INSERT VIDEO]` placeholders on a review-ready PR. If proof is missing, say so in chat, not as a fake link.

## Deployment Plan

Four bullets. Customer impact is *customer-visible* behavior, not employee-only chrome and not "this slice is incomplete".

- `Customer impact: No` — stop there when none
- `Customer impact: Yes. <what the user sees>` — one clause, not a design recap
- Rollout Plan: the actual gate (feature flag, employee-only, both)
- Rollback Plan: only document a rollback plan if there is a well-defined feature flag or Codegate to toggle off. If the only rollback path is reverting the PR ("Revert this PR"), default to `N/A`.
- Rollback Tested: `Yes`/`No` when a feature flag or Codegate rollback exists; default to `N/A` when Rollback Plan is `N/A`.

```
- Customer impact: No
- Rollout Plan: Employee-only behind the Analyst feature flag
- Rollback Plan: N/A
- Rollback Tested: N/A
```

```
- Customer impact: Yes. Users at or near an Analyst credit limit see a new banner, and hard-limited users see a disabled input.
- Rollout Plan: Gated by `NovaGatewayAnalystBudgetEnforce`. While it's off the endpoint reports `available: false` and nothing renders, input remains available
- Rollback Plan: Disable `NovaGatewayAnalystBudgetEnforce`
- Rollback Tested: No
```

## Red flags

- "This PR is a vertical slice…" / "already-reviewed code" / "lands in #26588–#26590"
- Summary mentions another PR
- Second sentence of architecture the diff already shows
- Customer impact explains gating that belongs in Rollout Plan
- Test plan is a CI checklist
- Overwriting a body the user just tweaked
