# ACE design sheet examples

## Sentence rewrites

| Bad | Good |
|---|---|
| Users with PermUse should somehow show up after we check grants. | Every user that has the PermUse permission appears in the roster. The system reads the grants for every agent domain. If a grant refers to a team, then the system expands the team into users. |
| Caching might help depending on load. | The gateway stores the budget policy in a cache. The cache lifetime is 60 seconds. If the cache does not contain the policy, then the gateway loads the policy from Freya. |
| We should probably put this in ACS or maybe a shared lib. | Option A places Check in nova-gateway as an in-process library. Option B places Check behind an ACS HTTP call. The design chooses Option A because Check must avoid an extra service hop. |
| It returns the wrong thing when V2 is on. | `analystBudgetUsageRoster` returns an empty user set when authz V2 is enabled. |
| Handle errors appropriately. | If the grant read fails, then statesvc returns an internal error. |
| Authz stuff TBD. | Does `AllUsersWithOrgPermission` need the same `ToV1Identity` conversion? |

## Mini design sheet

```markdown
# Budget usage roster identities under authz V2

- Status: Draft
- Owners: statesvc, authz
- Date: 2026-07-30
- Related: MCDB-97736

## Problem

The budget usage aggregate returns no user rows for an organization that has authz V2 enabled.

## Goals

1. The roster includes every user that has the PermUse permission on any agent domain.
2. The roster expands every team grant into member users.
3. The roster works for authz V1 identities and authz V2 identities.

## Non-goals

1. This change does not move usage reads into ACS REST.
2. This change does not redesign authz grant storage.

## Constraints

### Hard constraints

1. The fix must accept both `uuid.User` values and opaque authz V2 identity descriptors.
2. The public aggregate authz action remains `OrgActionInvoiceCalculate`.

### Preferences

1. Prefer a small local fix in the roster path over a broad authz refactor.

## Current behavior

1. `analystBudgetUsageRoster` type-asserts `grant.Identity` to `uuid.User` or `uuid.Team`.
2. Authz V2 returns opaque identities from `MakeIdentity`.
3. The type switch matches no V2 identity, so the roster is empty.

## Options

| Option | Behavior | Cost | Risk | Ops impact |
|---|---|---|---|---|
| A | Convert with `ToV1Identity` before the type switch | Low | Low | None |
| B | Change authz V2 to return typed UUIDs everywhere | High | High blast radius | Broad release risk |

## Decision

The design chooses Option A because the bug is local to consumers that type-assert identities.

- The design rejects Option B because a global identity-shape change is larger than the roster fix.

## Design

### API

1. `budgetUsageAggregate` keeps the same GraphQL contract.

### Control flow

1. statesvc loads domain grants through `AllGrantedRoles`.
2. statesvc converts each grant identity with `ToV1Identity`.
3. statesvc adds users and collects teams.
4. statesvc expands each team one time through `AllUserMembers`.

### Failure modes

| Failure | Behavior |
|---|---|
| Identity conversion fails | Return an error |
| Team expansion fails | Return an error |
| No PermUse roles exist | Return an empty user set |

### Ownership

| Concern | System |
|---|---|
| Roster construction | statesvc |
| Identity conversion helper | helios authz v2 |

## Rollout and validation

1. Migration: none.
2. Feature flag: none. The conversion is safe for V1 and V2.
3. Backfill or repair: none.
4. Metrics and alerts: none for this fix.
5. Proof plan:
   - Unit: V1-typed and V2-opaque user and team grants
   - Smoke: aggregate for an org with RBACRoleV2 enabled

## Open questions

1. Does `AllUsersWithOrgPermission` need the same `ToV1Identity` conversion?
```

## Common ACE mistakes in design sheets

1. **Missing determiner:** "Gateway caches policy." → "The gateway caches the policy."
2. **Hidden modality:** "should", "might", "could" without a decision. Replace with a chosen behavior or an open question.
3. **Noun stacks:** "user permission grant expansion process" → name the function `AllUserMembers`.
4. **Solution-first writing:** options before goals. Reorder the sheet.
5. **Person ownership:** "Adithya owns retries." → "nova-gateway owns retries."
