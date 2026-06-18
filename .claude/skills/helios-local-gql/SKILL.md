---
name: helios-local-gql
description: Use whenever the user wants to call the private GraphQL API (statesvc) in the Helios localdev stack — the one that needs a System JWT. Trigger on phrases like "call the private GQL", "hit the private graphql locally", "query statesvc", "send this GQL to the helios backend", "run this mutation against localdev", "get a System JWT", or any local GraphQL call against port 9001/private. Also trigger when the user pastes a raw GraphQL query/mutation and asks to run it against localdev.
---

# Helios local private GQL

Call `http://127.0.0.1:9001/private` (statesvc) without re-deriving auth plumbing each time. Delegates JWT generation to the canonical helios helper so this skill never forks secret-handling logic.

## Scope

- **In scope:** the **private** GraphQL API on statesvc (`:9001/private`) — the one most internal tooling hits.
- **Out of scope:** the `/public` endpoint (requires a real user/customer JWT, not a System JWT, so a helper doesn't simplify anything), nova-manager (`:8081/private`), and production/staging.

If the user needs `/public` or production, tell them this skill doesn't cover it and point at `helios/scripts/statesvc/run_unauthenticated_gql.sh` or the helios web app itself.

## Preferred tool: the bundled helper

Use `scripts/gql.py` (relative to this skill). It shells out to the helios helper for the JWT, retries transient errors, and pretty-prints JSON.

```
python3 ~/.claude/skills/helios-local-gql/scripts/gql.py \
  [--query '...' | --query-file PATH | -]     # or pipe via stdin
  [--operation OpName] \
  [--variables '{"k":"v"}'] \
  [--endpoint URL]                            # defaults to http://127.0.0.1:9001/private
  [--helios-repo /path/to/helios] \
  [--raw]                                     # skip JSON pretty-print
```

The script autodetects the helios repo via `$HELIOS_REPO`, then `~/projects/helios`, then `/home/jchi/projects/helios`.

### Worked examples

**Schema sanity check:**

```
python3 ~/.claude/skills/helios-local-gql/scripts/gql.py --query '{ __typename }'
```

**List workspaces for a project:**

```
python3 ~/.claude/skills/helios-local-gql/scripts/gql.py \
  --query 'query($p: ID!) { workspaces(projectID: $p) { workspaceID name state } }' \
  --variables '{"p":"00000000-0000-0000-0000-000000000000"}'
```

**Pipe a query file:**

```
cat my_query.gql | python3 ~/.claude/skills/helios-local-gql/scripts/gql.py
```

**Just print a System JWT (no request):** run the helios helper directly.

```
bash $HELIOS_REPO/local-dev-utilities/get_private_auth_header.sh
# -> Bearer eyJhbGciOi...
```

## How auth works

`gql.py` shells out to `$HELIOS_REPO/local-dev-utilities/get_private_auth_header.sh`, which calls `gen_system_token.py` → `scripts/statesvc/run_local_statesvc_operation.py` → reads `test/realm-secrets.json` and signs a short-lived System-realm JWT. Same flow that `start_nova_workspace.sh` and the analyst setup scripts use, so if those work, this works.

Requirements on the local Python env:
- `pyjwt` installed (and `cryptography` if the realm uses RS/ES keys).
- `test/realm-secrets.json` populated — done by `make kube-init`.

**Never re-implement this JWT flow here** — always delegate to the helios helper.

## Common failure modes

- **`connection refused` on :9001** — statesvc isn't up. Finish `make kube-init` and confirm the statesvc pod is running. See `babysit-init-analyst` if bring-up is stuck.
- **401** — JWT was rejected. Usually means statesvc restarted with fresh keys; regenerate by rerunning the script (JWTs are 1-hour TTL). If that doesn't fix it, `test/realm-secrets.json` is out of sync.
- **`Failed to generate System JWT`** — pyjwt missing or `realm-secrets.json` absent. Install pyjwt+cryptography and rerun `make kube-init`.
- **`errors: [...]` in a 200 response** — real GraphQL error. `gql.py` exits non-zero so it composes with shell pipelines; pass `--no-fail-on-errors` to ignore.
