---
type: research
title: "PR #22619: Batch Agent Domain Auth Checks — Deep Dive"
project: helios
area: singlestore.com/helios/authz, singlestore.com/helios/novaapps, graph/server/public
tags: [agent-domains, authorization, RBAC, batch, IsAuthorizedList, performance, N+1]
date: 2026-02-19
status: complete
---

# PR #22619: Batch Agent Domain Auth Checks

## Overview

PR #22619 replaces per-domain authorization checks in the `AgentDomains` GraphQL resolver with bulk variants, reducing 2N sequential DB queries (N feature-flag checks + N RBAC grant queries) down to 2 queries total. Three files were changed (93 additions, 12 deletions).

## Changed Files

| File | Change |
|------|--------|
| `singlestore.com/helios/authz/authzgql/util.go` | Added `IsGQLActionAuthorizedList` (lines 67–98) |
| `singlestore.com/helios/graph/server/public/agentdomains.go` | Rewrote `AgentDomains` resolver loop (lines 77–93) |
| `singlestore.com/helios/novaapps/novarbac.go` | Added `CheckAgentDomainAccessList` (lines 132–167) |

---

## Call Chain (New Code)

```
AgentDomains resolver (agentdomains.go:82)
  └─ novaapps.CheckAgentDomainAccessList (novarbac.go:132)
       ├─ featureflags.OrgHasFeatureFlag (orgfeatureflags.go:14)
       │    • single DB query for all feature flags on the org
       │    • returns true if ANY of the provided flags match (OR semantics)
       │    • flags checked: FeatureFlagIDNovaRbac, FeatureFlagIDRBACAuthorization
       │
       ├─ [if !ok — no feature flag] → return all-true slice (RBAC not enforced)
       │
       ├─ [if GateRBACEmployeeGroups codegate enabled]:
       │    └─ authzgql.IsGQLActionAuthorizedList (util.go:67)
       │         ├─ realm.System → all-true
       │         ├─ realm.Employee → check group membership once, apply to all
       │         └─ realm.Customer → authorizer.IsAuthorizedList (impl/authorization.go:81)
       │
       └─ [else — codegate disabled]:
            ├─ action.ToPermission() → maps AgentDomainActionAgentDomainUse to authz.PermUse
            └─ env.Authorizer.IsAuthorizedList (impl/authorization.go:81)
```

## Call Chain (Old Code, for comparison)

```
AgentDomains resolver (agentdomains.go — old)
  └─ FOR EACH domain:
       └─ novaapps.CheckAgentDomainAccess (novarbac.go:100)
            ├─ featureflags.OrgHasFeatureFlag  ← called N times
            ├─ [if GateRBACEmployeeGroups enabled]:
            │    └─ authzgql.IsGQLActionAuthorized (util.go:28)
            │         └─ authorizer.IsAuthorized  ← called N times
            └─ [else]:
                 └─ authzgql.IsAuthorizedForGQL (util.go:102)
                      └─ authorizer.IsAuthorized  ← called N times
```

---

## Deep Dive: Each Function in the New Code

### 1. `CheckAgentDomainAccessList` — `novarbac.go:132–167`

Bulk variant of `CheckAgentDomainAccess`. Structure:

1. **Feature flag check** (line 140): `OrgHasFeatureFlag(ctx, conn, orgID, NovaRbac, RBACAuthorization)` — single query. If neither flag is set, returns all-true (RBAC not enforced for this org).
2. **Build resource slice** (lines 152–156): Converts `[]uuid.AgentDomain` → `[]authz.Resource` and sets `parents = []authz.Resource{orgID}`.
3. **Codegate branch** (line 158): If `GateRBACEmployeeGroups` is enabled, delegates to `IsGQLActionAuthorizedList`.
4. **Legacy branch** (lines 162–166): Maps action to permission via `action.ToPermission()`, then calls `env.Authorizer.IsAuthorizedList` directly.

### 2. `IsGQLActionAuthorizedList` — `util.go:67–98`

Bulk variant of `IsGQLActionAuthorized`. Handles realm-based dispatch:

- **No claims** (line 69–71): Returns `nil, error` with HTTP 401.
- **System realm** (line 80): Returns all-true immediately.
- **Employee realm** (lines 81–89): Calls `action.ToEmployeeGroups()` once, checks `c.IsMember(...)` once. If member, all-true. If not member, all-false (`make([]bool, len(resources))` — zero-valued bools).
- **Customer realm** (lines 92–97): Calls `action.ToPermissions()` once, then `authorizer.IsAuthorizedList()` once.

### 3. `authorizer.IsAuthorizedList` — `impl/authorization.go:81–196`

Production RBAC engine. Key behaviors:

1. **Empty resources** (line 94–96): Returns `nil, nil`.
2. **`prepare(ctx, resources[0], parents)`** (line 104): Uses **only the first resource** for scope resolution and identity extraction. All resources must share the same org parent for this to be correct (which they do — all agent domains belong to the same org).
3. **Single DB query** (line 131): `getGrants(ctx, whereForResourcesList(resources, parents), whereForIdentities(identities))` builds an `OR` clause across all resource IDs + parent IDs, fetching all grants in one query.
4. **Per-resource grant evaluation** (lines 136–186): Iterates over resources, checks cache first, then processes grants via `forEachGrantedRole`. Caches results per-resource.
5. **Type homogeneity enforced** (line 137–138): All resources must be the same type; returns error otherwise.
6. **Special error cases**:
   - `ErrDisabled` → all-true (RBAC disabled for org)
   - `ErrUnauthorizedOrganization` → all-false (wrong org scope)

### 4. `whereForResourcesList` — `impl/db.go:233–244`

Builds an `sq.Or` clause for the SQL query:
```sql
WHERE (resourceType = 'AgentDomain' AND resourceID = '<id1>')
   OR (resourceType = 'AgentDomain' AND resourceID = '<id2>')
   ...
   OR (resourceType = 'Organization' AND resourceID = '<orgID>')
```

### 5. `OrgHasFeatureFlag` — `featureflags/orgfeatureflags.go:14–30`

- Queries all feature flags for the org (single DB query).
- Returns `true` if **any** of the given flags match (OR semantics).
- Called with `FeatureFlagIDNovaRbac, FeatureFlagIDRBACAuthorization`.

### 6. `AgentDomainAction` methods — `graph/authz.go:373–398`

- **`ToPermission()`** (line 388): Maps action to single permission. `AgentDomainActionAgentDomainUse` → `authz.PermUse`.
- **`ToPermissions()`** (line 392): Wraps `ToPermission()` into `[]authz.Permission`.
- **`ToEmployeeGroups()`** (line 396): Maps action to employee groups for group-membership checks.

---

## Behavioral Differences: Old vs. New

### Error Handling

| Scenario | Old Behavior | New Behavior |
|----------|-------------|-------------|
| Domain unauthorized (403) | `CheckAgentDomainAccess` returns error → resolver catches 403 via `errors.As(err, &gqlErr)`, skips domain | `CheckAgentDomainAccessList` returns `false` in bool slice → resolver skips domain |
| Non-auth error on one domain | Resolver returns error for that specific domain: `"failed to check agent domain (%s) access"` | Resolver returns error for entire batch: `"failed to check agent domain access"` |
| Feature flag check error | Returns `"unable to verify authorization"` per domain (but resolver returns on first error) | Returns `"unable to verify authorization"` once for all domains |

### Database Queries

| Scenario | Old | New |
|----------|-----|-----|
| N domains, RBAC enabled | N feature-flag queries + N grant queries = 2N | 1 feature-flag query + 1 grant query = 2 |
| N domains, RBAC disabled | N feature-flag queries = N | 1 feature-flag query = 1 |

### Edge Cases

| Case | Old | New |
|------|-----|-----|
| 0 domains | Loop doesn't execute; returns empty slice | `CheckAgentDomainAccessList` called with empty `agentDomainIDs`; `IsAuthorizedList` returns `nil, nil`; loop doesn't execute; returns empty slice |
| Employee not in group (codegate path) | Returns 403 error per domain, each caught and skipped | Returns all-false bool slice, all domains skipped |
| `IsAuthorizedList` returns error | N/A (was per-item `IsAuthorized`) | Entire resolver fails with `"failed to check agent domain access"` |

---

## Key Code References

| Component | File | Lines |
|-----------|------|-------|
| `AgentDomains` resolver | `singlestore.com/helios/graph/server/public/agentdomains.go` | 49–96 |
| `CheckAgentDomainAccess` (original) | `singlestore.com/helios/novaapps/novarbac.go` | 100–126 |
| `CheckAgentDomainAccessList` (new) | `singlestore.com/helios/novaapps/novarbac.go` | 132–167 |
| `IsGQLActionAuthorized` (original) | `singlestore.com/helios/authz/authzgql/util.go` | 28–60 |
| `IsGQLActionAuthorizedList` (new) | `singlestore.com/helios/authz/authzgql/util.go` | 67–98 |
| `Authorizer` interface | `singlestore.com/helios/authz/authorization.go` | 14–29 |
| `IsAuthorizedList` production impl | `singlestore.com/helios/authz/impl/authorization.go` | 81–196 |
| `IsAuthorizedList` test/mock impl | `singlestore.com/helios/authz/test/inmem/authorization.go` | 90–100 |
| `prepare` (scope/identity setup) | `singlestore.com/helios/authz/impl/authorization.go` | 482–521 |
| `whereForResourcesList` (SQL builder) | `singlestore.com/helios/authz/impl/db.go` | 233–244 |
| `OrgHasFeatureFlag` | `singlestore.com/helios/featureflags/orgfeatureflags.go` | 14–30 |
| `AgentDomainAction` type & methods | `singlestore.com/helios/graph/authz.go` | 373–398 |
| `agentDomainActionMap` | `singlestore.com/helios/graph/authz.go` | 373–380 |
| `IsAuthorizedForGQL` (used by old path) | `singlestore.com/helios/authz/authzgql/util.go` | 102–123 |
| `GateRBACEmployeeGroups` codegate | `singlestore.com/helios/authz/authzgql/util.go` | 18 |
| `toAgentDomainGraphQL` | `singlestore.com/helios/graph/server/public/agentdomains.go` | 524–536 |
