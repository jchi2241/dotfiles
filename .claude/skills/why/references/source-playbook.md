# Source playbooks

The why skill spawns one investigator per available evidence category, each reading a single source-specific playbook below. The playbooks are concrete examples for common MCPs. Adapt them for a different MCP in the same category.

On this machine, use these sources:

| Category | Source here |
|---|---|
| Issue / ticket tracker | Atlassian Jira (`plugin-atlassian-atlassian`). Adapt `linear.md`. |
| Long-form documents | Confluence, Glean (`user-glean` search, then read_document), Google Drive. Adapt `notion.md`. |
| Real-time team chat | Slack (`plugin-slack-slack`). |
| Infrastructure observability | Grafana (`user-grafana`). Adapt `datadog.md`. |
| Incidents | PagerDuty (`user-pagerduty`), with `incident-postmortem.md`. |
| Error tracking, product analytics warehouse | No MCP. Record the gap. Do not invent a source. |

| Category | Playbook | Example MCP it documents |
|---|---|---|
| Source control history | [`code-archaeology.md`](./sources/code-archaeology.md) | git, `gh` |
| Issue / ticket tracker | [`linear.md`](./sources/linear.md) | Linear (adapt for Jira, GitHub Issues, Plane, Shortcut) |
| Long-form documents | [`notion.md`](./sources/notion.md) | Notion (adapt for Confluence, Google Docs, Coda) |
| Real-time team chat | [`slack.md`](./sources/slack.md) | Slack (adapt for Discord, Microsoft Teams, Mattermost) |
| Infrastructure observability | [`datadog.md`](./sources/datadog.md) | Datadog (adapt for New Relic, Honeycomb, Grafana, Splunk) |
| Error / exception tracking | [`sentry.md`](./sources/sentry.md) | Sentry (adapt for Rollbar, Bugsnag, Airbrake) |
| Product analytics warehouse | [`databricks.md`](./sources/databricks.md) | Databricks SQL (adapt for Snowflake, BigQuery, ClickHouse, dbt) |

Cross-cutting:

- [`incident-postmortem.md`](./sources/incident-postmortem.md). Add this if the target code looks defensive (null checks, retry, timeout, rate limit, feature flag, egress guard, OOM handler).
