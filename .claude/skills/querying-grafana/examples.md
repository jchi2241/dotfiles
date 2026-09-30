# Example Grafana queries

## Analyst installs (Postgres `freya`)

Datasource `postgres/helios-prd-ro`. Analyst agents are `notebookcodeservice.name LIKE 'sqlbot-%'`. Canonical `nexusapps` is MySQL `helios`, not Postgres.

```sql
SELECT g.name AS org_name,
       o.groupid::text AS org_id,
       o.internal,
       COUNT(DISTINCT p.projectid) AS projects,
       COUNT(*) AS sqlbot_services,
       COUNT(*) FILTER (WHERE ncs.status IN ('Idle','Active')) AS healthy_services
FROM notebookcodeservice ncs
JOIN projects p ON p.projectid = ncs.projectid
JOIN organizations o ON o.groupid = p.orgid
JOIN groups g ON g.groupid = o.groupid
WHERE ncs.deletedat IS NULL
  AND ncs.name LIKE 'sqlbot-%'
GROUP BY 1, 2, 3
ORDER BY o.internal, g.name;
```

Org name from UUID:

```sql
SELECT g.name, o.groupid::text, o.internal, o.terminatedat
FROM organizations o
JOIN groups g ON g.groupid = o.groupid
WHERE o.groupid = '<uuid>'
LIMIT 1;
```

## Nexus apps (MySQL `helios`)

Datasource `kubera-prod (helios)`.

```sql
SELECT appID, projectID, status, installedAt, terminatedAt, versionID
FROM helios.nexusapps
WHERE appType = 'AuraAnalyst'
  AND terminatedAt IS NULL
ORDER BY installedAt DESC
LIMIT 200;
```

## Billing messages (MySQL `kubera`)

Datasource `kubera-prod`. Analyst meter used by adoption dashboards: `f639c8e0-2cc7-4394-b966-5bbaad964704`. Always time-filter `effectiveat`.

```sql
SELECT JSON_EXTRACT_STRING(ru.tags, 'orgId') AS org_id,
       c.name AS org_name,
       SUM(ru.amount) AS messages
FROM resourceusage ru
LEFT JOIN customer c ON JSON_EXTRACT_STRING(ru.tags, 'orgId') = c.customerid
WHERE ru.meterid = 'f639c8e0-2cc7-4394-b966-5bbaad964704'
  AND ru.effectiveat >= DATE_SUB(NOW(), INTERVAL 7 DAY)
  AND ru.tags IS NOT NULL
GROUP BY org_id, org_name
ORDER BY messages DESC
LIMIT 50;
```

## Failed Helios tasks (Postgres)

```sql
SELECT taskid,
       kind,
       state,
       payload -> 'data' ->> 'operation' AS operation,
       payload -> 'data' ->> 'projectID' AS project_id,
       createdat
FROM tasks
WHERE kind IN ('AuraAnalystTask', 'NexusAppTask')
  AND state = 'Failed'
  AND createdat > NOW() - INTERVAL '24 hours'
ORDER BY createdat DESC
LIMIT 50;
```

## Loki: UMG / Nova errors

Datasource `loki/helios`. Stats first:

```
{cell="aws-virginia-novaprd1", namespace="fission", app="unified-model-gateway"}
```

Then lines (`limit` 20–50, incident `startRfc3339`/`endRfc3339`):

```
{cell="aws-virginia-novaprd1", namespace="fission", app="unified-model-gateway"} |= "error forwarding request"
```

## Loki: nova-gateway Analyst

```
{cell="aws-virginia-novaprd1", namespace="fission", app="nova-gateway"} |= "auraanalyst"
```

Confirm `app` with `list_loki_label_values` (`labelName=app`, same 15m window, after you already know `cell`+`namespace`). App cardinality is high — never list it unfiltered over a long range.
