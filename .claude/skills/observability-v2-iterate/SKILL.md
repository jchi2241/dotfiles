---
name: observability-v2-iterate
description: Use this skill when iterating on the Analyst observability_v2 Python package at ai-apps/bot/analyst/source/observability_v2/ inside singlestore-nexus. Trigger on phrases like "test this against the analyst", "let me repair and send a request", "run repair", "grep the live logs", "send another request to the analyst", or any request to debug observability_v2 changes against the running local analyst. This skill captures the strict commit→push→SHA-bump→refresh-nexus cadence and the live-logs.jsonl grep workflow that replaces generic kubectl log tailing.
---

# observability_v2 Iteration Workflow

Changes to the `observability_v2/` Python package don't take effect in the running Analyst until the new code is published on GitHub (via a bumped `NEXUS_SHA` in `sqlbot.ipynb`) AND the notebook pod has re-executed cell 7 to `pip install` from that SHA. That second step only happens when the user calls `auraAnalystRepair`. So the loop is split: Claude does everything up to and including `refresh-nexus`, then the user does the repair + test request, then Claude reads logs.

Never edit `sqlbot.ipynb` content except to bump `NEXUS_SHA`. Anything else belongs in the `observability_v2/` package.

## The loop

```
[Claude] code change in observability_v2/
[Claude] commit + push to the current branch
[Claude] bump NEXUS_SHA in sqlbot.ipynb cell 7
[Claude] make refresh-nexus
[Claude] call auraAnalystRepair via helios-local-gql
[Claude] ask user to send a test request
---
[User] sends a test request to the analyst
[User] tells Claude the request is done
---
[Claude] greps /var/log/aura/live-logs.jsonl in the active notebook pod
[Claude] summarizes what happened, proposes next change
```

Do not spawn background log tailers. Read logs on-demand only after the user confirms they sent a request. Background tails die when pods restart (and repair restarts pods) so they're unreliable; on-demand grep is simpler and always works against whichever pod is current.

## Step 1 — Make code changes

Edit files under `~/projects/singlestore-nexus/ai-apps/bot/analyst/source/observability_v2/`.

**Prototype mode — log liberally.** The live-logs file is the primary debugging surface (not user-facing). Add `logging.getLogger("observability_v2.<module>").info(...)` at every meaningful lifecycle point: tool ENTER/EXIT, wrapper ENTER/EXIT, writer construction, ContextVar binds, forward_events loop iterations. Include arg values verbatim — `sql=%r thoughts=%r` — and short object reprs (`id=%x title=%r`). Over-logging is correct here.

## Step 2 — Commit and push

Use the current branch (don't create a new one per iteration). Write a short message describing the change; the user iterates fast and long messages are noise.

```bash
cd ~/projects/singlestore-nexus
git add ai-apps/bot/analyst/source/observability_v2/<files>
git commit -m "[WIP] observability_v2: <short summary>"
git push
git rev-parse HEAD   # capture this SHA for step 3
```

## Step 3 — Bump NEXUS_SHA in sqlbot.ipynb

The notebook is too large for the Read tool, so NotebookEdit (which requires a prior Read) also fails. Use `jq` for an in-place substitution. Cell 7's id is `obs-v2-install-arc1`.

```bash
cd ~/projects/singlestore-nexus/ai-apps/bot/analyst/source
jq --arg old "<PREVIOUS_SHA>" --arg new "<NEW_SHA>" \
  '(.cells[] | select(.id == "obs-v2-install-arc1") | .source) |= map(gsub($old; $new))' \
  sqlbot.ipynb > /tmp/sqlbot.ipynb.new
\cp -f /tmp/sqlbot.ipynb.new sqlbot.ipynb

# Verify
jq -r '.cells[7].source | join("")' sqlbot.ipynb | grep NEXUS_SHA
```

The leading `\` on `\cp` bypasses any `cp` alias that prompts for overwrite.

If you don't know the previous SHA, read it first:
```bash
jq -r '.cells[7].source | join("")' sqlbot.ipynb | grep '^NEXUS_SHA'
```

**Report the full 40-char SHA back to the user**, not the 7-char shorthand. The shorthand forces the user to run an extra `git log` to find the real commit; the full SHA doesn't.

## Step 4 — make refresh-nexus

This syncs the working tree (including the notebook with the new SHA) into the k3d cluster's state-service mount at `/var/singlestore-nexus`. state-service serves the notebook file to notebook pods from there.

```bash
cd ~/projects/helios && direnv exec . make refresh-nexus
```

The `direnv exec .` is required — the helios repo has a `.envrc` that sets up `kubectl` against the local k3d cluster, and without it commands will target the wrong context (or fail).

## Step 5 — Call auraAnalystRepair, then ask user to test

`auraAnalystRepair` is the private-GraphQL mutation that kicks state-service to re-install the notebook (picks up the bumped `NEXUS_SHA` and runs cell 7 against the new commit). Call it directly via the `helios-local-gql` skill's `gql.py` helper — no reason to wait for the user.

```bash
python3 ~/.claude/skills/helios-local-gql/scripts/gql.py \
  --query 'mutation($p: ProjectID!) { auraAnalystRepair(projectID: $p) }' \
  --variables '{"p":"<PROJECT_ID>"}'
```

Expected response: `{"data": {"auraAnalystRepair": true}}`.

**Finding the project_id:** if you don't know it yet, the current session's project shows up repeatedly in live-logs (look for the `projects/<uuid>/checkpoints/...` URL the aura-context-svc HTTP requests walk through). In this tree the local dev project is `21948690-2df5-46bc-83cb-6db9e31897cd`. If that's wrong, grep the newest live-logs once and you'll see the real one.

### Reporting back

After refresh-nexus + repair, just make sure the **full 40-char SHA** is in the response — the user pastes it into the prod Analyst bump, so shorthand forces an extra `git log` step. No template, no headers. Short and loose is fine.

## Step 6 — Read live logs after user confirmation

All `kubectl` commands must be prefixed with `direnv exec ~/projects/helios`.

### Pick the active notebook pod

Notebook pods are named `notebooks-cpu--<uuid>-0` under the `default` namespace. Multiple may be present from previous sessions. Pick the one whose `/var/log/aura/live-logs.jsonl` has nonzero size and the most recent mtime:

```bash
direnv exec ~/projects/helios kubectl get pods -n default | grep notebooks-cpu
```

Then for each candidate:
```bash
direnv exec ~/projects/helios kubectl exec -n default <pod> -- \
  stat -c "mtime: %y  size: %s" /var/log/aura/live-logs.jsonl
```

Pick the one with the largest size (or most recent mtime) — that's the one the user's session is writing to.

### Tail the logs

The pod often lacks `jq` and `python3` (the one in the notebook kernel is at `/opt/conda/bin/python`, not on PATH in `sh`). Keep it simple: `tail` + `cut`.

```bash
direnv exec ~/projects/helios kubectl exec -n default <pod> -- sh -c '
  wc -l /var/log/aura/live-logs.jsonl
  echo ---
  tail -60 /var/log/aura/live-logs.jsonl | cut -c1-400
'
```

Line truncation matters — each log line is a single-line JSON object and can easily be >2000 chars. `cut -c1-400` keeps Claude's view readable.

Filter for observability_v2 / subagent lifecycle events:
```bash
direnv exec ~/projects/helios kubectl exec -n default <pod> -- sh -c '
  grep -E "observability_v2|forward_events|subagent|bind_thinking_writer|execute_controlplane_query|execute_metric_query" /var/log/aura/live-logs.jsonl | tail -40 | cut -c1-500
'
```

For full JSON parsing, run a Python one-liner against the full-path kernel python:
```bash
direnv exec ~/projects/helios kubectl exec -n default <pod> -- /opt/conda/bin/python -c '
import json
for line in open("/var/log/aura/live-logs.jsonl").readlines()[-30:]:
    d = json.loads(line)
    print(d.get("severity_text"), d.get("body")[:200])
'
```

## Key facts

- `pulse_otel.setup_json_file_logger()` (auto-prepended to every notebook kernel by `executor.go`) routes `logging.root` through an OTel handler that writes JSONL to `$LIVE_LOGS_FILE_PATH = /var/log/aura/live-logs.jsonl`. Any `logger.info(...)` call inside observability_v2 lands in that file.
- `/var/singlestore-nexus/` is mounted at the k3d **node** level. state-service reads from there; notebook pods do **not** have that path mounted directly. `make refresh-nexus` updates what state-service sees, and state-service then serves the updated notebook to the jupyter content API for newly-started kernels.
- `uv pip install --target=/home/jovyan/.obs_v2_site` is what cell 7 does. After `auraAnalystRepair`, a fresh pod runs cell 7 which fetches `observability_v2` at the NEXUS_SHA. Check what's installed in a pod with `ls /home/jovyan/.obs_v2_site/observability_v2/` and grep for a signature string from your latest change to confirm new code is live.
- If the pod has the OLD code despite a recent SHA bump: the pod started before your `refresh-nexus` landed. Ask the user to repair again.
