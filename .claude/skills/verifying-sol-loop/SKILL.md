---
name: verifying-sol-loop
description: Use when the user explicitly asks to verify with a sol-medium subagent, run a cheap verification loop, or invokes this skill by name. Manual only — do not auto-run after rebases, commits, or PR work.
disable-model-invocation: true
---

# Cheap sol-medium verification loop

Gate the current work with a cheap independent check. The main agent keeps the original task. A fresh verifier reports issues. The main agent fixes. Repeat until PASS. Then the main agent continues the original task.

**Manual only.** Do not start this loop unless the user invoked this skill.

## Loop

1. Main agent finishes the work-in-progress it wants checked. Leave a clean git state if possible.
2. Dispatch a **fresh** verifier (do not resume a prior verifier).
3. If **PASS**: stop the loop. Continue the original task (push, restack, next step).
4. If **FAIL**: main agent fixes only the listed issues. Go to step 2 with a **new** verifier.
5. Cap at **3** FAIL cycles. After that, report remaining issues and wait.

Do not skip a re-verify after a fix. Do not continue the original task on FAIL.

## Verifier dispatch

- Model: GPT 5.6 sol medium. In Cursor, `model: gpt-5.6-sol-medium` on `Task` with `subagent_type: generalPurpose`.
- Read-only. No commits, checkouts, rebases, restacks, pushes, or file edits.
- Give a concrete checklist for **this** change, plus repo path, branch, and what "done" means. Do not paste huge diffs; point at refs and files.

Ask for:

```
Verdict: PASS or FAIL
Each checklist item with evidence
If FAIL: exact fixes required, file paths, why
Residual risks that are out of scope (do not fail on these)
```

PASS means every checklist item holds. Residual risks (no full CI, remote not fetched) do not flip PASS to FAIL.

## Cheap vs forbidden

The **verifier and the fix loop** must stay cheap. Do not run Helios-scale builds or lints to "prove" the work.

**Forbidden:** `make backend-compile`, `make backend-compile-changed`, `make lint-backend`, `make backend-lint`, `make backend-gopls-validate`, `make backend-generate`, `make backend-graphql`, `make backend-test`, `make frontend-test`, and any other full-repo generate/compile/lint/CI job.

**Allowed:** `git` read commands, `rg`, Read, Glob. One tiny targeted test (`go test ./one/package`) only when the checklist needs it and it is already fast.

If a fix seems to require a forbidden command, stop and ask. Targeted `gqlgen --config <one yml>` is a **fix**, not a verification step — do it only as a listed FAIL fix, then cheap-verify again.

## Red flags

- Starting this loop unprompted
- Using compile/lint/generate as the verifier
- Resuming the same verifier after a fix
- Treating "looks fine to me" as PASS without a verifier report
- Restacking, pushing, or moving on while the last verdict is FAIL
