---
name: debugging-umg-incidents
description: Use when investigating Unified Model Gateway (UMG) PagerDuty incidents, UnifiedModelGateway5xxErrors, writing or tightening an RCA, mapping which org/service caused UMG 5xx/503s, or drafting a Slack summary of a UMG page.
---

# Debugging UMG PagerDuty incidents

Investigate first. Write a tight RCA second. Do not assume the last incident's cause.

Playbook: https://memsql.atlassian.net/wiki/spaces/Luna/pages/4306534440/UMG+On-call+Playbook
Dashboard: https://grafana.aws-virginia-hm1.svc.singlestore.com/d/aura-umg/unified-model-gateway

## Investigate

1. **PagerDuty** — incident, alerts, notes, related `UnifiedModelGateway5xxErrors` the same day. Alert body has cell/namespace/rate. PD MCP can fail (`tool_groups`); then curl:

   ```bash
   source ~/.dotfiles/.shell/secrets.sh
   curl -sS -H "Authorization: Token token=${PAGERDUTY_API_TOKEN}" \
     -H "Accept: application/vnd.pagerduty+json;version=2" \
     "https://api.pagerduty.com/incidents/<ID>"
   ```

   Same for `/alerts` and `/notes`. Never print the token.

2. **Scope Grafana to the alert window**, not a rolling 1h that misses onset. Default cell `aws-virginia-novaprd1`, namespace `fission`. Mimir UID `fewybmy2sok5cc`.

3. **What actually 5xx'd** — `sum by (code, path, model)` on `umg_http_requests_total`. Then cause (`umg_upstream_errors_total`), upstream HTTP (`umg_upstream_response_status_total`), volume, in-flight, p99.

4. **Who** — `sum by (singlestore_org_id, singlestore_project_id, nexus_app_type, nexus_app_id, type)`. Label is `singlestore_org_id`, not `org_id`.

5. **Logs** — Loki datasource **`loki/helios`** (`f559aee0-88c1-4151-b9ec-499efb79b6a1`). Pulse Loki (`bfoprho3fc54we`) 502s often. Filter `cell="aws-virginia-novaprd1"`. Errors are nested JSON in `_entry`; search `context canceled`, `error forwarding request`, `ConversePassthrough`.

6. **Code only to confirm a hypothesis** (status mapping, `classifyUpstreamFailure` fallbacks). Copy-paste PromQL: [queries.md](queries.md).

## Classify (do not mix)

| Signature | Meaning |
|---|---|
| HTTP 500 + `bedrock_translate_failed` + logs `context canceled` | Client cancel, **mislabeled** 500. Not a Bedrock outage. |
| HTTP 503 ≈ `umg_upstream_response_status_total{provider="AWS", code="503"}` | Real Bedrock 503, proxied (`ConversePassthrough` copies `resp.StatusCode`). |
| 503 + `retry_exhausted` / "error forwarding request" | UMG reverse-proxy retry exhausted, not Bedrock passthrough. |

UMG pages land on PagerDuty service **Analyst** even when the traffic is not Analyst. Trust `nexus_app_type`, not the PD service name.

`type="Customer"` is the Helios **realm**, not "external customer". Sharehouse (`00aa0f2e-4092-4677-b89a-4e52f75cdb41`) is an **employee/internal** org.

Look up the org **human name** (Glean the UUID, or admin portal). Same-day auto-resolved pages of the same alert are flaps, not new failures.

## Tenant + service

Always resolve:

- **Org** — human name + UUID. `(Employee)` or `(Customer)`. Admin: `https://portal.singlestore.com/admin/organizations/organization?orgID=<uuid>`
- **Project** — UUID, linked. Admin: `https://portal.singlestore.com/admin/projects/project?projectID=<uuid>`
- **Service** — from `nexus_app_type`: `AuraAnalyst` → Analyst, `AIFunctions` → AI Functions. If unlabeled, say so.

## RCA (tight)

Lead with cause in one sentence. Include org (named), Employee/Customer, service, numbers, window, what you ruled out in one line, one suggestion.

Do not pad with yesterday's unrelated incident. Do not dump timelines unless the user asks. If they want copy-paste, put the whole RCA in one fenced block (use a 4-backtick outer fence if the RCA contains a code fence).

## Slack

No headers, no tables. `*bold*`, bullets, `[text](url)`. Org line is a portal-admin link + `(Employee)` or `(Customer)`. Same for project. Service is a short name.

**Where to post**

| Service | Channel |
|---|---|
| AI Functions | `#ai-ml-functions` first; `#udf-ai-ml-function-ga` if GA/on-call |
| Analyst | `#analyst` / `#analyst-dev` as appropriate |
| UMG itself | `#luna` (private) for gateway owners |
| Don't | `#luna-alerts`, `#sharehouse-data-eng` unless Sharehouse data platform is actually broken |

## Slack shape

```
*UMG 5xx [#N]* — one-sentence cause. Status.

*Org:* [Human Name](admin org url) (Employee|Customer)
*Project:* [uuid](admin project url)
*Service:* Analyst | AI Functions | …

- 2–4 bullets: counts, window, cell, evidence
*Suggestion:* one line

PD url
```
