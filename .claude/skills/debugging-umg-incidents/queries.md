# UMG Grafana queries

Mimir: `fewybmy2sok5cc`. Default matchers: `cell="aws-virginia-novaprd1"`.

## What 5xx'd

```promql
sum by (code, path, model) (
  increase(umg_http_requests_total{cell="aws-virginia-novaprd1", code=~"5.."}[30m])
) > 0
```

Per-5m for a known route:

```promql
sum(increase(umg_http_requests_total{
  cell="aws-virginia-novaprd1", code=~"5..",
  model="openai.gpt-5.6-luna", path="/responses"
}[5m]))
```

Status mix:

```promql
sum by (code) (
  increase(umg_http_requests_total{
    cell="aws-virginia-novaprd1",
    model="anthropic.claude-haiku-4-5-20251001-v1:0", path="/converse"
  }[30m])
)
```

## Cause vs real upstream HTTP

```promql
sum by (cause, model, provider) (
  increase(umg_upstream_errors_total{cell="aws-virginia-novaprd1"}[30m])
) > 0
```

```promql
sum by (code, provider) (
  increase(umg_upstream_response_status_total{cell="aws-virginia-novaprd1"}[30m])
) > 0
```

If 503 HTTP ≈ AWS `umg_upstream_response_status_total` 503 → Bedrock returned 503.
If 500 HTTP ≈ `bedrock_translate_failed` and logs say `context canceled` → mislabel.

## Who

```promql
sum by (singlestore_org_id, singlestore_project_id, nexus_app_type, nexus_app_id, type) (
  increase(umg_http_requests_total{
    cell="aws-virginia-novaprd1", code=~"5.."
  }[30m])
)
```

## Saturation

```promql
sum(umg_http_requests_in_flight{cell="aws-virginia-novaprd1"})
```

```promql
histogram_quantile(0.99,
  sum by (le) (rate(umg_http_requests_duration_seconds_bucket{
    cell="aws-virginia-novaprd1", model="openai.gpt-5.6-luna", path="/responses"
  }[5m]))
)
```

Duration buckets top out at 10s — saturated p99 means tail is worse, not exactly 10s.

## Logs (Loki `f559aee0-88c1-4151-b9ec-499efb79b6a1`)

```logql
{namespace="fission", app="unified-model-gateway-deployment", cell="aws-virginia-novaprd1"}
  |= "context canceled"
```

```logql
{namespace="fission", app="unified-model-gateway-deployment", cell="aws-virginia-novaprd1"}
  |= "error forwarding request"
```

```logql
{namespace="fission", app="unified-model-gateway-deployment", cell="aws-virginia-novaprd1"}
  |= "ConversePassthrough"
```

## Known orgs

| UUID | Name | Kind |
|---|---|---|
| `00aa0f2e-4092-4677-b89a-4e52f75cdb41` | S2DB DATA - Sharehouse | Employee |
| `50d43c38-e0c7-4169-9cea-66d955fce497` | (internal; confirm name via Glean/admin) | Employee |

Do not treat this table as complete. Always Glean/admin-verify new UUIDs.
