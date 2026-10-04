# Helios verification map

How to reach and drive each Helios surface on the local stack. Lanes read the files for the surfaces their claim drives; the claims themselves come from the diff.

| Feature | File |
|---|---|
| Analyst chat turn, end to end | [`analyst-chat.md`](analyst-chat.md) |
| Analyst budget: contracted vs on-demand, limits, enforcement | [`analyst-budget.md`](analyst-budget.md) |
| Agent chat billing: which agents meter, sidebar agent install | [`agent-billing.md`](agent-billing.md) |

## Baseline

- `scripts/doctor.sh` passes.
- The portal at `http://localhost:8001` is `make frontend-start` from the worktree under test.
- Local users are seeded by `kube-init` from `local.sql`. Every password is `Password!`.

| User | Org | Use for |
|---|---|---|
| `employee@singlestore.com` | SingleStore Org `d7d4c050-3ced-49e1-8cff-a7e8eb95e691`, project `21948690-2df5-46bc-83cb-6db9e31897cd` | Analyst. `make setup-analyst` enables its flags on this org only. |
| `customer@email.com` | Local Dev Org `c7e83804-2e49-4dcf-bbd4-27fd7ad28d5d` | Non-Analyst customer pages |
| `employee@email.com` | Admin portal at `http://localhost:8001/admin` | Admin pages |

## Conventions

- Start each recipe from the baseline unless its preconditions say otherwise.
- Prefer ARIA roles, labels, placeholders, and `data-testid` over CSS classes or position.
- Treat commands and quoted names as literal.

## Feature file shape

Each file starts with an H1 and one paragraph on the user-visible behavior, then these four H2 sections in order:

1. `Sub-features`: short IDs, one line each.
2. `How to get to it (user POV)`: every user entry point.
3. `Driving it`: `Preconditions:`, then labeled steps pairing each user action with the exact command and the observable result.
4. `Gotchas`: traps that waste or invalidate a run.
