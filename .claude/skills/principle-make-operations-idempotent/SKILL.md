---
name: principle-make-operations-idempotent
description: "Apply when writing anything that changes stored state and can run more than once: backfills, install hooks, data migrations, retries, upserts, queue consumers, setup scripts. A second run changes nothing, and a run that stopped halfway finishes cleanly."
disable-model-invocation: true
---

# Make Operations Idempotent

Every operation that changes state answers two questions before it ships: what happens if it runs twice, and what happens if the last run crashed halfway?

**Why:** Retries, redeploys, and reruns are normal. If the next run's result depends on what the last run left behind, every rerun is a debugging session, and a backfill cannot be safely restarted.

**How:**

- Converge on the end state; do not apply a step. Insert when missing (`ON CONFLICT DO NOTHING`, or a unique index plus a skip) instead of insert-and-hope.
- Never overwrite a value a person or an earlier run already set, unless overwriting is the point. Merge into JSONB with `details || jsonb_build_object(...)`; do not replace the whole document.
- An increment is not idempotent. Make the write and its read-back one transaction so a failure does not commit a half-counted delta, and accept or dedupe retries on purpose.
- Make each unit of work independent. A backfill processes one org per transaction, so a rerun after a crash finishes the rest and skips the done ones.
- Report what a run did: inserted, skipped, failed, with totals. Two runs in a row should show the second one skipping everything.

**The test:**

1. Run it twice in a row. Does the second run change nothing?
2. Kill it at each step. Does the next run converge to the same end state?
3. Run it against a row a person already edited. Is their value intact?

If any answer is "it depends on what was left behind," add the reconciliation step.

**Tells:**

- A plain `INSERT` in a backfill or install hook.
- An `UPDATE ... SET details = $1` on a JSONB column other writers use.
- A setup script that fails on its second run.
- A retry loop around a non-idempotent call.
