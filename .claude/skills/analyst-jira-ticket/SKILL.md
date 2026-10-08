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
- Issue type: `Epic`, `Story`, `Bug`, or `Sub-task`. Never create a `Task`.
  - Hierarchy: epic > story (or bug) > sub-task.
  - If the operator asks for a "task", create a `Story`.
  - `Story` for any outcome: a feature, a doc or one-pager, or technical follow-up.
  - `Bug` when the operator calls it a bug, or it fixes broken behavior.
  - `Epic` when the operator asks for an epic, or for a body of work spanning several stories.
  - `Sub-task` only under a story, with that story as `parent`.
- Search before creating when the request may duplicate prior Analyst work.

## Granularity

- The story is the main unit of work. Add sub-tasks under it only when the operator asks.
- Several PRs reference the same story key in their titles. Only the last PR of the story uses `#closes`.
- Implementation details live in the spec and the plan, not in Jira. A story names its outcome and links the spec.
- A migration apply ticket is the exception. File it with the `helios-migration-jira-ticket` skill.

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

**Subdomain:** always `memsql.atlassian.net` for Jira/Confluence browse and wiki
links. Never use `singlestore.atlassian.net` — that host is wrong for this org.

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

## Finding the Analyst sprints

Sprint IDs roll over, so look them up instead of hardcoding. Read
`customfield_10021` off recent Analyst tickets:

```
searchJiraIssuesUsingJql
  jql: project = MCDB AND labels = Analyst AND sprint in openSprints() ORDER BY updated DESC
  fields: ["summary", "customfield_10021"]
```

`openSprints()` returns active and future sprints.
The `state: "active"` entry is the current sprint, and the earliest `state: "future"` entry is the next one.
Naming pattern is `Analyst-Sprint-<year>-<n>` on two-week cadence.
If no ticket sits in a future sprint yet, list the sprints of board `2902` (`discover` "list sprints for a board").
If the board has no future sprint, use the active sprint and say the next one doesn't exist yet.

## Sprint placement

Decide the sprint yourself; don't ask, and never leave a ticket in the backlog unless the operator says so.

- **Active sprint, In Progress:** work is already underway, or starts now (the operator says "in progress", "start", or is doing it in this session).
- **Active sprint, left Qualified:** not started, but it is small enough to finish before the active sprint's `endDate` and nothing blocks it.
- **Next sprint, left Qualified (to do):** it depends on unmerged or unscheduled work, it is a follow-up, the operator says "later" or "next", or the active sprint ends within 3 days.

State the choice and the reason in the reply, for example "next sprint (Analyst-Sprint-2026-6): blocked on Phase 1".

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

1. Look up the sprint IDs and pick one per "Sprint placement".
2. `createJiraIssue` with `projectKey: "MCDB"`, `issueType` (`Story`, `Bug`, `Epic`, or `Sub-task`), `summary`,
   `description` (markdown is accepted and converted), and `additional_fields`
   carrying `labels`, `components`, and `customfield_10017`. Pass the sprint ID as
   `assignToSprint` and the account ID as `assignee`. `customfield_10021` in
   `additional_fields` is rejected on create ("Specify a valid value for Sprint").
3. Only when placement says In Progress: `getTransitionsForJiraIssue`, then `transitionJiraIssue` to In Progress.
4. Re-read the issue to confirm epic, sprint, assignee, and status all stuck —
   board automation can override the status you just set.

When the ticket has a PR, put the key at the end of the PR title
(`[category] summary MCDB-xxxxx`, per `pr-create`) so Helios CI links them; add
the PR URL under `## Related` in the description.
