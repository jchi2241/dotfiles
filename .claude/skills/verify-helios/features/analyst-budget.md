# Analyst budget

A billing manager opens Billing & Usage, then Budget, sees how many Analyst credits the org used this month, and sets monthly limits. When a limit is hit, Analyst chat and the Analyst API stop answering. Whether the org has a contract (a commitment or a monthlyBundle) or is on-demand (no contract, or PAYG) decides which limits exist and who can change them.

## Sub-features

- `budget-contract` switches the org between contracted and on-demand, and reverts it.
- `budget-tab` shows usage and saves the Users and API limits under `Configure`.
- `budget-org` shows and saves the Organization limit. This doesn't exist yet; it lands with MCDB-100995 PR-5 and PR-10.
- `budget-admin-set-limit` sets the org limit from the admin portal. This lands with PR-12.
- `budget-chat-notice` shows the chat notice when the org limit blocks a question. This lands with PR-11.
- `budget-enforce` makes a question over the limit fail with a 429 in both the portal and the API.

## How to get to it (user POV)

- Customer portal: `http://localhost:8001/organizations/d7d4c050-3ced-49e1-8cff-a7e8eb95e691/billing#budget`. Sidebar **Billing**, then the **Budget** tab. The tab only renders for orgs with the `Analyst` flag.
- Edit: the `Configure` button on the Analyst panel, which opens the `Monthly Budget` flyout. It only renders for billing managers.
- Admin portal: `http://localhost:8001/admin`, signed in as `employee@email.com`, on the org's page. The exact entry point gets filled in when PR-12 lands.
- Chat notice: the Analyst chat from [`analyst-chat.md`](analyst-chat.md), once a limit is reached.

## Driving it

Preconditions:

- [`analyst-chat.md`](analyst-chat.md) preconditions hold, and its install stages are done. Enforcement checks need a working chat turn.
- `EVIDENCE=~/Pictures/verify-helios/<YYYY-MM-DD_HHMM>_analyst-budget` exists.
- These helpers are set in a bash shell started from `~/projects/helios`:

  ```bash
  G(){ python3 ~/.claude/skills/helios-local-gql/scripts/gql.py "$@"; }
  P=21948690-2df5-46bc-83cb-6db9e31897cd
  MONTH=$(date -u +%Y-%m-01T00:00:00Z)
  NEXT_YEAR=$(date -u -d "$MONTH +1 year" +%Y-%m-%dT%H:%M:%SZ)
  ```

Steps:

- **Read contract state (`budget-contract`).** Run this before and after every change, and save each output to `$EVIDENCE/contracts-<label>.json`:

  ```bash
  G --no-fail-on-errors --query 'query($p: ObjectID!){ project(id:$p){
    billingContracts{ contractType startAt endBefore deletedAt active }
    analystBillingRates{ creditsPerQuestion usdPerQuestion } } }' --variables "{\"p\":\"$P\"}"
  ```

  The org is on-demand when there is no `active: true` row, or only `contractType: PAYG` rows. Otherwise it's contracted. Classify on `active`, not on whether any rows exist.
- **Make contracted (monthlyBundle).** `startAt` must be the first day of the current UTC month. An earlier date counts as backdated and needs `force`.

  ```bash
  G --query 'mutation($i: BookSubscriptionCreateInput!){ bookSubscriptionCreate(input:$i){ bookSubscriptionID } }' \
    --variables "{\"i\":{\"projectID\":\"$P\",\"cellGroupID\":\"00000000-0000-0000-0000-000000000000\",\"metric\":\"ComputeMicroHour\",\"delta\":10000000,\"bundleSize\":\"Medium\",\"startAt\":\"$MONTH\",\"endBefore\":\"$NEXT_YEAR\",\"unitRate\":3.6,\"expiration\":\"contract\",\"contractURI\":\"verify-helios\",\"amountUSD\":432}}"
  ```

  Save the ID as `BUNDLE`. The read shows one `monthlyBundle` with `active: true`, and `analystBillingRates` returns `creditsPerQuestion: 0.125`.
- **Make contracted (commitment), as an alternative.** Use `commitCreate` with `{contractURI, projectID: $P, delta: 1000000000, metric: "ComputeMicroHour", startAt: $MONTH, endBefore: $NEXT_YEAR, amountUSD: 10000}`. Don't create both kinds at once.
- **Make on-demand with PAYG.** Use `commitCreate` with `commitType: PAYG` and metric `PAYGComputeMicroHour`. The read shows `contractType: PAYG`, which counts as on-demand.
- **Revert to on-demand.** For the bundle: `G --query 'mutation($id: BookSubscriptionID!){ bookSubscriptionDelete(bookSubscriptionID:$id){ deletedAt } }' --variables "{\"id\":\"$BUNDLE\"}"`. For a commit: `commitDelete(id:<commitID>, force:true)`. Afterward the read shows no `active: true` row. Revert at the end of every run, even if the run failed.
- **Budget tab (`budget-tab`).** Log in as in `analyst-chat.md`, open the Budget URL, and screenshot `$EVIDENCE/10-budget-<contracted|on-demand>.png`. Click `Configure`, change `Monthly allowance per user` or `Monthly API credit cap`, and save. Reload, and confirm the value persisted.
- **Org limit, admin set-limit, and chat notice (`budget-org`, `budget-admin-set-limit`, `budget-chat-notice`).** The PR that adds each one also adds its exact labels and steps here.
  - **Contracted org:** the org limit can be edited.
  - **On-demand org:** the org limit is locked, and the admin portal can still set it to any value.
  - **Chat notice:** record the blocked question with `page.video().start/stop`, as in `analyst-chat.md`.
- **Enforcement (`budget-enforce`).** Set a limit at or below current usage, then send a question as in `analyst-chat.md`. The chat shows the budget alert, and Nova Gateway logs a 429 for the turn. Restore the old limit afterward.

## Gotchas

- Contracts live in the local SingleStore tables `bookcommit` and `booksubscription`, not in Postgres `freya`. A `psql` query shows nothing, so use the GraphQL reads.
- A deleted bundle stays in `billingContracts` with `active: false`. Rows pile up over runs, and that's expected.
- Deleting an already-deleted bundle fails. Create a fresh bundle each run.
- `analystBillingRates` errors unless exactly one non-PAYG contract is active ("found (2)" or "found (0)"). That error is useful: in the on-demand state, "found (0)" is the expected result.
- Don't use `Organization.contractType`. It's a different classifier that needs a `CloudStandardV1` plan and counts credit packages.
- Two overlapping commits of the same type fail unless `replace: true` is passed.
- The System JWT from `gql.py` passes every billing-manager check. Use it to set up state, never as proof that a billing manager can do something; drive that part through the portal.
- Only SingleStore Org has Analyst flags. To compare two orgs side by side, flag Local Dev Org (`c7e83804-2e49-4dcf-bbd4-27fd7ad28d5d`, project `0ad091ac-b313-4e4f-89dc-01f3ec6ec5c1`, user `customer@email.com`). `featureFlagOrgBulkUpdate` refuses `SingleIntelligence` for a customer org ("flag is not available for customers"), so insert the flags into Freya `featureflags` directly and invalidate the flag cache: `SingleIntelligence, Analyst, NovaRBAC, UseConversationStarters, AmazonAnalyst, AzureAIModels`. Skip `NovaBilling` unless the project has a subscriptions row, or install returns 402. Rerun the `auraContextStoreCreate` mutation from `local-dev-utilities/analyst/03_setup_ai_services.sh` with that project; without it the install is accepted but the task Fails. Remove the flags afterward.
- A hard per-user override (quota 0) shows `enforcementType: hard` only when the Default row's `onLimitExceed` is `Block`; the gateway takes hard/soft from the Default row, not the override. Clear it afterward.
- A gateway chat turn without the portal: `POST :8000/v1/organizations/{org}/projects/{proj}/agents/chat` with `{user_input, org_id, project_id, agent_service_id}` (Analyst's agent service ID is in `notebookcodeservice` for the project). Without `agent_service_id` it routes to another agent and returns 400.
