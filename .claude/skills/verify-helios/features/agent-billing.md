# Agent chat billing

Each completed chat turn on Nova Gateway `/agents/chat` can produce one Analyst usage event and count against the Analyst portal budget. Which agents get billed depends on the agent container's nexus app type: Analyst, or a sidebar agent (Flow, Observability, Support, Query Tuning).

## Sub-features

- `bill-analyst` means a completed Analyst turn produces a billing event.
- `bill-sidebar` means a completed sidebar-agent turn produces a billing event, or doesn't.
- `sidebar-install` installs a sidebar agent locally so it can be chatted with.

## How to get to it (user POV)

- Analyst: as in [`analyst-chat.md`](analyst-chat.md).
- Sidebar agent: the header's `Ask SingleStore` button opens the sidebar. Its `Agent` combobox lists one option per agent whose flag is on, such as `Flow Agent`.

## Driving it

Preconditions:

- The [`analyst-chat.md`](analyst-chat.md) preconditions hold.
- `--code-gates` in `kubectl get deploy -n fission nova-gateway-deployment -o jsonpath='{.spec.template.spec.containers[0].args[5]}'` includes `NovaGatewayAnalystMetering`. Billing gates are set by the statesvc build that created the deployment, not by the nova-gateway image. A new gate is missing until statesvc runs the code that adds it. Until then, append it to that arg with `kubectl patch --type=json` and say so in the verdict.

Steps:

- **Deploy a build.** From the worktree under test, run `direnv exec . make kube-rebuild-nova-gateway`, then `kubectl rollout restart -n fission deploy/nova-gateway-deployment`. Confirm the running pod's `imageID` digest matches the pushed digest. A raw `git worktree add` worktree needs `GOFLAGS=-buildvcs=false` and `go/bin/dlv`; set it up like `wta`.
- **Scrape.** `kubectl get --raw "/api/v1/namespaces/fission/pods/$POD:9999/proxy/metrics" | grep '^nova_gateway_billing_events'`. The counter series is absent until the first increment.
- **Install a sidebar agent (`sidebar-install`).** The steps for Flow:
  1. `featureFlagOrgBulkUpdate` with `AuraFlow` on SingleStore Org.
  2. `nexusAppVersionCreate` with `appType: AuraFlow`, `version: "1.0.0-dev"`, `schemaFilePath: "/var/singlestore-nexus/ai-apps/agents/packages/flow/install/install.yaml"`, and the `singlestore` publisher. Then call `nexusAppVersionPromote` twice.
  3. Call public `nexusAppInstall(input:{projectID, appType: AuraFlow, region:"us-east-1"})` from the logged-in page with `fetch`, reusing the `authorization` header of a portal `localhost:9001/public` request. The local private schema has no `nexusAppInstall`.
  4. The app turns `Active` within a minute and exposes an `Agent` resource.

  The two `nexusAppVersionPromote` calls are optional locally: in dev, install picks the latest supported version of the app type whatever its tag. Read the `singlestore` publisher ID with `mysql -u root -h localhost -P 3310 -ppassword helios -e "select publisherid from nexusapppublishers where name='singlestore'"`.
  The local `novaagent` image prebakes all five agent packages under `/opt/agents`.
- **Chat.** Pick `Flow Agent` in the sidebar, fill `getByRole('textbox', { name: /Ask me to migrate data/ })`, and click `getByRole('button', { name: 'Ask', exact: true, disabled: false })`. On the Analyst page the main composer has its own disabled `Ask`, so without `disabled: false` the locator matches two buttons and fails strict mode. Wait for `Stop` to detach. Then scrape again and read nova-gateway logs since the send: `producing billing event`, or `not billing nexus app type <type> on service <id>`.

## Gotchas

- Sidebar Flow sessions also show up in the Analyst page's History list. Count them when you delete sessions.
- `/organizations/<org>/dashboard` is a 404. The sidebar still works there, but open it from a real page for screenshots.
- `initializeNovaContainerForAgents` is on State SVC `/public` and needs a Customer-realm user token (Nova Gateway forwards the user's). A System JWT from `helios-local-gql` is rejected there before schema validation (`internal server error`, statesvc logs `not authorized`). Agent services live in Postgres `notebookcodeservice` (`isagent`).
