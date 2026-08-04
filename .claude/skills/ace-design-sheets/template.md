# Design sheet template

Copy this skeleton. Keep the headings. Fill each section in Attempto Controlled English (ACE). Delete a section only when it does not apply.

```markdown
# <Feature name>

- Status: Draft | Review | Accepted
- Owners: <systems or packages>
- Date: YYYY-MM-DD
- Related: <ticket IDs, PR links>

## Problem

<What broken behavior or missing capability does the user see?>

## Goals

1. <Testable required outcome.>
2. <Testable required outcome.>

## Non-goals

1. <Outcome that this release excludes.>
2. <Outcome that this release excludes.>

## Constraints

### Hard constraints

1. <Limit that blocks an option.>

### Preferences

1. <Preference that ranks options but does not block them.>

## Current behavior

1. <What the system does today.>
2. Relevant code: `<package/path>` — `<entrypoint or type>`.

## Options

| Option | Behavior | Cost | Risk | Ops impact |
|---|---|---|---|---|
| A |  |  |  |  |
| B |  |  |  |  |

### Option A

<Short ACE description.>

### Option B

<Short ACE description.>

## Decision

The design chooses Option <X> because <one primary reason>.

- The design rejects Option <Y> because <one sentence>.

## Design

### Data

1. <Tables, keys, null meaning, retention.>

### API

1. <Inputs, outputs, authz action, error shape.>

### Control flow

1. <Step.>
2. <Step.>
3. <Step.>

### Failure modes

| Failure | Behavior |
|---|---|
| <dependency or input failure> | <fail-open or fail-closed result> |

### Ownership

| Concern | System |
|---|---|
| Config source of truth |  |
| Hot-path enforcement |  |
| Usage read API |  |

## Rollout and validation

1. Migration: <order and compatibility>.
2. Feature flag: <name and default>.
3. Backfill or repair: <plan or none>.
4. Metrics and alerts: <signals>.
5. Proof plan:
   - Unit: <what>
   - Integration: <what>
   - Smoke: <what>

## Open questions

1. <ACE question>?
2. <ACE question>?
```
