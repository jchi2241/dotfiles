---
name: analyst-jira-ticket
description: Use when creating or updating Jira tickets for Helios Analyst, Aura Analyst, SQL Bot, Analyst API key, Analyst install, subscription, billing, trial credits, or Analyst request-path work.
---

# Analyst Jira Ticket

Use this for Jira tickets about the SingleStore Analyst / Aura Analyst / SQL Bot in Helios.

## Defaults

- Jira project: `MCDB`
- Label: `Analyst` (capitalized — matches existing Analyst tickets; JQL matching is case-insensitive)
- Component: `Analyst` (not `AI & Compute Platform`)
- Preferred type:
  - `Story` for feature/enforcement/product behavior
  - `Bug` for observed broken behavior or regression
  - `Task` for technical follow-up/refactor
- Search before creating when the request may duplicate prior Analyst work.

## Known Analyst Context

Analyst spans:
- Portal UI: `frontend/src/pages/organizations/intelligence/`
- State SVC / public GraphQL: `singlestore.com/helios/graph/server/public/`
- Analyst tasks: `singlestore.com/helios/nexusapps/auraanalyst*.go`
- Nova Gateway API/key paths: `singlestore.com/helios/cmd/nova-gateway/`

Subscription requirement learned from MCDB-96656:
- Analyst does not require a specific plan tier.
- Runtime Nova billing only requires at least one active, non-expired subscription.
- Trial credit exhaustion expires the trial subscription, so `!hasActiveSubscriptions` means trial exhausted for trial orgs.
- Backend runtime check: `novabilling.ValidateProjectSubscriptionForPool`.
- That check runs from `nova.DequeueContainer` only when `FeatureFlagIDNovaBilling` is enabled.

## Description Pattern

For enforcement tickets, include:

```markdown
## Problem

[Who can do what today, and why that is bad.]

## Goal

[The desired eligibility rule and where it should fail.]

## Proposed approach

- Backend: [resolver/handler/check location]
- Frontend: [button/banner/error handling, if applicable]
- Error: return/show `BillingNoActiveSubscription` or a clear subscription message

## Acceptance criteria

- [ ] Ineligible orgs are blocked when `FeatureFlagIDNovaBilling` is enabled and no active subscription exists.
- [ ] Orgs with active subscriptions are unaffected.
- [ ] The error is user-actionable.
- [ ] Tests cover the blocked path and at least one allowed path.

## Related

- [Existing MCDB ticket or PR, if any]
```

## MCP Details

Use the Atlassian MCP server (`plugin-atlassian-atlassian`). Always read the tool schema first.

Useful tools:
- `searchJiraIssuesUsingJql`
- `createJiraIssue`
- `editJiraIssue`
- `getTransitionsForJiraIssue`
- `transitionJiraIssue`
- `lookupJiraAccountId`
- `createIssueLink`

Every call needs `cloudId`. For memsql it is `1a9d89cb-3ee6-412b-849e-74a5dd4bbdf7`
(the site URL `memsql.atlassian.net` also works for most tools, but the UUID is
safest). Confirm with `getAccessibleAtlassianResources` if a call rejects it.

After creating a follow-up ticket, link or at least reference the parent ticket in the description.

## Field IDs (MCDB / Helios Cloud)

Set these through `additional_fields` on create, or `fields` on edit:

| Field | ID | Value shape |
|-------|-----|-------------|
| Epic link | `customfield_10017` | Epic key string, e.g. `"MCDB-90950"` (also populates `parent`) |
| Sprint | `customfield_10021` | Numeric sprint ID, e.g. `10185` — **not** the sprint name |
| Component | `components` | `[{"name": "Analyst"}]` (id `21469`) |
| Labels | `labels` | `["Analyst"]` |

## Known IDs

- Analyst GA epic: `MCDB-90950` — "Analyst GA Readiness: Dev & SRE"
- Analyst board: `2902`
- Justin Chi (`jchi@memsql.com`): `557058:4dbbea40-3f6d-4a79-a74d-cea0491299a3`

## Finding the current Analyst sprint

Sprint IDs roll over, so look one up instead of hardcoding. Read
`customfield_10021` off a recent Analyst ticket:

```
searchJiraIssuesUsingJql
  jql: project = MCDB AND labels = Analyst AND sprint in openSprints() ORDER BY updated DESC
  fields: ["summary", "customfield_10021"]
```

The `state: "active"` entry is the current sprint (e.g. `Analyst-Sprint-2026-N`).
Naming pattern is `Analyst-Sprint-<year>-<n>` on two-week cadence.

## Transitions

New tickets land in `Backlog`, and board automation may move them to `Qualified`
once a sprint is set. Neither is "In Progress" — transition explicitly.

Common transition IDs on MCDB Task/Story (verify with
`getTransitionsForJiraIssue`, since they vary by workflow and current status):

| Transition | ID | Target status |
|------------|-----|---------------|
| Start | `161` | In Progress |
| Blocked | `11` | Need Info |
| Backlog | `191` | Backlog |
| Close | `221` | Closed (has screen) |

## Create recipe

Sprint and epic can both be set on the initial `createJiraIssue` call; only the
status needs a second step.

1. Look up the active sprint ID (above).
2. `createJiraIssue` with `projectKey: "MCDB"`, `issueTypeName`, `summary`,
   `description` (markdown is accepted and converted), and `additional_fields`
   carrying `labels`, `components`, `customfield_10017`, `customfield_10021`, and
   `assignee: {"id": "<accountId>"}`.
3. `getTransitionsForJiraIssue`, then `transitionJiraIssue` to In Progress.
4. Re-read the issue to confirm epic, sprint, assignee, and status all stuck —
   board automation can override the status you just set.

When the ticket has a PR, put the key in the PR title (`MCDB-xxxxx: ...`) so
Helios CI links them; add the PR URL under `## Related` in the description.
