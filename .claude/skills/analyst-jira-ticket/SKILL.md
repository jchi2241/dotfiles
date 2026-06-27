---
name: analyst-jira-ticket
description: Use when creating or updating Jira tickets for Helios Analyst, Aura Analyst, SQL Bot, Analyst API key, Analyst install, subscription, billing, trial credits, or Analyst request-path work.
---

# Analyst Jira Ticket

Use this for Jira tickets about the SingleStore Analyst / Aura Analyst / SQL Bot in Helios.

## Defaults

- Jira project: `MCDB`
- Label: `analyst` (lowercase unless matching an existing ticket requires otherwise)
- Component: `AI & Compute Platform`
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

Use `user-atlassian` MCP when available. Always read the tool schema first.

Useful tools:
- `jira_search`
- `jira_get_issue`
- `jira_create_issue`
- `jira_update_issue`
- `jira_create_issue_link`

When creating:
- `project_key`: `MCDB`
- `components`: `AI & Compute Platform`
- `additional_fields`: `{"labels":["analyst"]}`

After creating a follow-up ticket, link or at least reference the parent ticket in the description.
