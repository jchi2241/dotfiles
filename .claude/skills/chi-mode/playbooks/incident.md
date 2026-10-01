# Incident playbook

For a PagerDuty page, a production error spike, or a customer-reported outage.
Read-only by default. Acknowledging, resolving, or changing production needs the user's go.

1. **Scope.** Read the incident with the PagerDuty tools: service, start time, alert, current state. For a Unified Model Gateway (UMG) page, switch to the `debugging-umg-incidents` skill and follow it.
2. **Gather signals** for the incident window.
   - Metrics and logs: `querying-grafana` (Prometheus, Loki, Postgres, SingleStore).
   - Traces: `pulse-traces`.
   - Recent changes: deploys, codegate flips, and merged PRs in the window (`why` source-control playbook).
3. **Classify.** Name the failing component, the affected tenants or orgs, and whether it is ongoing. Keep separate causes separate.
4. **Find the cause.** State one hypothesis and prove it with a query or trace. Mark anything unproven as a hypothesis.
5. **Mitigate, with the user.** Propose the smallest lever: disable a codegate, roll back, scale. Do not act without the user's go.
6. **Fix.** A code fix follows `bug-fix.md`. An urgent production fix follows `hotfix.md`.
7. **Write up.** A tight RCA: symptom, impact, timeline, root cause, why it was not caught, fix, follow-ups. Draft the Slack summary per `~/.claude/VOICE.md`. Post only after the user approves.

**Reply:** current status and impact first, then the cause with its evidence, then the proposed next action.
