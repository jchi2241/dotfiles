---
name: pulse-traces
description: Use this skill whenever the user wants to pull a trace, span, or logs out of the Pulse OTel store — the SingleStore database that backs the /traces UI. Trigger on phrases like "pull trace X", "show me logs for span Y", "check which span the logs attached to", "query pulse.otel_traces", "look up this trace_id", "open pulse", or any request that boils down to "I have a trace ID, show me what's in it". Also trigger when the user shares Pulse connection info (`svc-*.svc.singlestore.com` + admin password) and wants Claude to run queries against it. Do NOT use for the local notebook's `/var/log/aura/live-logs.jsonl` — that's the `observability-v2-iterate` skill.
---

# Pulse trace/log fetcher

Pulse stores OTel traces and logs in a SingleStore database per workspace.
When the user hands over a trace ID (or a span ID, or asks "what's in
trace X"), they almost always want one of:

- The span tree for the trace — to see what ran and how spans nest.
- Logs attached to a specific span — to see what code printed while that
  span was active.
- A "log attachment" diagnostic — "are my logs landing on the tool span
  I expect, or piling onto the root?" This one comes up when the
  /traces UI's Logs tab looks empty for tool spans.

`scripts/pulse.py` is the shortcut. Don't write ad-hoc Python from
scratch — invoke the script with the right subcommand and pipe the
output. If the shape isn't supported, read `references/schema.md` and
write the one-off query inline.

## Connection

Pulse has a separate SingleStore workspace per customer/project. The
user will hand you a host + password. Set env vars once per session:

```bash
export PULSE_HOST='svc-<uuid>-dml.<region>.svc.singlestore.com'
export PULSE_PASSWORD='<admin pw>'
# PULSE_USER defaults to admin, PULSE_PORT to 3306, PULSE_DB to pulse
```

Then invoke the script via the singlestoredb-equipped venv:

```bash
SSDB=/home/jchi/projects/singlestore-ai/.venv/bin/python
$SSDB ~/.claude/skills/pulse-traces/scripts/pulse.py <subcommand> ...
```

Everything after this assumes that prefix.

A trace_id is unique within a workspace only — so if the user gives you
a new connection string mid-session, swap the env vars, don't assume the
old trace_id exists there.

## Subcommands

### `trace <trace_id>` — first thing to run

```bash
$SSDB .../pulse.py trace 4a1a58dbe9ad81ebc7c6b7cb97aa3592
```

Prints: total span/log counts, the full span tree with parent/child
indentation and per-span log counts, and the tail of the trace's logs.
This is the "what happened in this request" view and usually enough by
itself.

If the tree is large (hundreds of spans), pass `--json` and pipe to
`jq` to extract a subtree:

```bash
$SSDB .../pulse.py --json trace <tid> \
  | jq '.spans[] | select(.name | contains("subagent"))'
```

### `span <span_id>` — zoom into one span

```bash
$SSDB .../pulse.py span 9340fcd0d321ad35
```

Shows the span's metadata plus the logs attached to it specifically.
Useful after `trace <tid>` reveals an interesting span id.

### `logs ...` — filtered log tail

```bash
$SSDB .../pulse.py logs --trace <tid> --scope observability_v2
$SSDB .../pulse.py logs --trace <tid> --grep "find_tables"
$SSDB .../pulse.py logs --span <sid> --severity ERROR
```

At least one of `--trace`/`--span`/`--scope`/`--grep`/`--severity` is
required. Combines with AND.

### `attachment <trace_id>` — which span did each log land on?

```bash
$SSDB .../pulse.py attachment <tid>
```

Histogram of log count per span_id. If one span has 90%+ of the logs —
especially if it's a root span — the downstream tool/sub-agent spans
aren't being activated as the current span, so `logger.info(...)` calls
emit with the ancestor's span_id. That's a common finding when
Langchain/Traceloop auto-instrumentation creates spans via
`tracer.start_span(...)` but never `start_as_current_span(...)`.

## When the script isn't enough

Read `references/schema.md`. It has the column list for both tables
plus the queries that come up most. For a one-off query:

```python
import singlestoredb as s2, os
conn = s2.connect(host=os.environ["PULSE_HOST"], port=3306,
                  user="admin", password=os.environ["PULSE_PASSWORD"],
                  database="pulse")
cur = conn.cursor()
cur.execute("SELECT ... FROM otel_traces WHERE ... LIMIT 20")
for r in cur: print(r)
```

Use the same venv python. Don't try `mysql` (not installed) or add
`pymysql` (not installed globally).

## Output discipline

Log bodies are truncated to 200 chars by default. If the user asks for
the full message of a specific log, pass `--full` to the relevant
subcommand. The truncation is there because it's easy to lose the shape
of a trace under 2000-char lines.

## Reporting

When summarizing for the user after fetching, lead with:

1. Span count, total log count.
2. The specific finding they asked about — in one sentence.
3. Only then the supporting detail.

Avoid dumping the full span tree into chat unless they ask — if it's
long, save it to a file and point them at it, or show the abbreviated
tree (top two levels) and say "full tree in <path>".
