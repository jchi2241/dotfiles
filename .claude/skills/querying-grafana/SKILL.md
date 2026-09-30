---
name: querying-grafana
description: >-
  Use when querying Grafana Postgres, MySQL/SingleStore, or Loki (helios-prd-ro,
  kubera-prod, nexusapps, pulse, monitoringdb, loki/helios) for on-call,
  incidents, RCA, Analyst installs, org lookups, or production data analysis.
  Also when choosing a Grafana datasource UID, writing LogQL or Grafana SQL,
  or the user says "query grafana", "postgres prd ro", or "loki logs".
---

# Querying Grafana

Helios Grafana: `https://grafana.aws-virginia-hm1.svc.singlestore.com`

Read [datasources.md](datasources.md) for UIDs. Read [examples.md](examples.md) for copy-paste queries.

Do not invent UIDs. If a name is missing or a query 404s, `list_datasources` and `get_datasource`.

## Pick a source

| Need | Source | UID |
|---|---|---|
| Orgs, projects, tasks, Nova apps, Analyst agents | `postgres/helios-prd-ro` (DB `freya`) | `c1f98863-a36a-4232-9261-751710e34223` |
| Nexus apps / versions (`helios.nexusapps`) | `kubera-prod (helios)` (DB `helios`) | `cew6je1mdqqyoe` |
| Billing, credits, `resourceusage` | `kubera-prod` (DB `kubera`) | `a0b11825-21e0-4ca5-a8fd-d21c2d76c080` |
| Helios/Nova service logs | `loki/helios` | `f559aee0-88c1-4151-b9ec-499efb79b6a1` |
| Preview Helios Postgres | `Postgres/helios-pvw-ro` | `be3pf2xaeibcwc` |
| Staging Helios Postgres | `postgres/helios-stg-ro` | `f810fdcc-bdee-42fe-9b70-0a4e61b7fcdd` |
| Pulse OTel in Grafana | `pulse/aura-telemetry` (MySQL, DB `pulse`) | `bfoprho3fc54we` |
| Per-cluster monitoring S2 | `monitoringdb-<clusterUUID>%` | look up UID; do not scan all |

`postgres/heliosdb-prd-us-east-*-ro` is the same `freya` control plane on Aurora cluster readers. Prefer `postgres/helios-prd-ro` unless that replica is down.

`postgres/customer-grafana-*` is Grafana's own DB (`grafana`), not Helios orgs.

`loki/system` hits the same Loki frontend as `loki/helios` with a different tenant header. Default to `loki/helios`. Cell Loki sources (`loki/aws-*`) are customer-cell logs, not Helios control plane.

Pulse **Loki** often 502s. Prefer `loki/helios` for service logs; use `pulse-traces` skill for workspace Pulse SQL.

UMG pages: also read `debugging-umg-incidents`.

## Query budget (always)

1. **Time-box.** Incidents: the alert window, not a rolling 1h that misses onset. Loki tools default to last 1h / 10 lines — set `startRfc3339` / `endRfc3339` and `limit`.
2. **Narrow first.** Loki: `{cell, namespace, app}` before `|=`. SQL: `WHERE` on IDs, `deletedat IS NULL`, `LIMIT`.
3. **Cheap probe.** Loki: `list_loki_label_values` then `query_loki_stats` (selector only) before pulling lines. SQL: `information_schema` / `COUNT(*)` with the same filters before wide SELECTs.
4. **Project columns.** No `SELECT *` on `tasks`, `resourceusage`, `notebookcodeservice`.
5. **Stop if empty/huge.** If stats show a firehose, add labels. Do not raise `limit` past 100 unless the user asked for a dump.
6. **Cite.** Name the datasource, UID, time range, and the filter that made it cheap. Give an Explore deeplink via `generate_deeplink`.

## How to run

**Loki** — `query_loki_logs` / `query_loki_stats` / `list_loki_label_*`. Do not use `grafana_api_request` for LogQL.

Helios/Nova on-call selector:

```
{cell="aws-virginia-novaprd1", namespace="fission", app="<service>"}
```

Control-plane Helios: `namespace="helios-prd"`, cells `aws-virginia-cpprd1` / `aws-ohio-cpprd1`.

Never `{namespace="fission"}` without `cell`. `namespace="fission"` exists on every Nova cell.

**Postgres / MySQL** — `grafana_api_request` `POST /api/ds/query`:

```json
{
  "queries": [{
    "refId": "A",
    "datasource": { "uid": "<uid>", "type": "<type>" },
    "rawSql": "<sql>",
    "format": "table"
  }]
}
```

Types: Postgres `grafana-postgresql-datasource`, MySQL `mysql`. Grafana SQL is read-only grafana users — still treat prod as production data (PII, customer names).

## Output

Lead with the answer (counts, org list, cause). Then source + window. Do not paste full Grafana JSON frames — extract columns. For large org/install tables, a canvas is fine.
