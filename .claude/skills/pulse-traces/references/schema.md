# Pulse OTel schema cheat sheet

The Pulse trace/log store is a SingleStore database. Two tables matter:
`pulse.otel_traces` for spans, `pulse.otel_logs` for log records. Each log
record carries `trace_id` + `span_id` FK into otel_traces.

Don't memorize column types — query `DESCRIBE pulse.otel_traces` when you
need them. The below is the minimum you'll reference to write queries.

## otel_traces (spans)

| column | notes |
| --- | --- |
| `trace_id` (pri) | hex string, 32 chars typically |
| `span_id` (pri) | hex string, 16 chars |
| `parent_span_id` | empty string `''` for root, not NULL |
| `span_name` | e.g. `sqlbot-20260423215646`, `ChatOpenAI.chat`, `execute_controlplane_query.tool` |
| `span_kind` | `Internal`, `Client`, `Server`, `Producer`, `Consumer` |
| `start_time_unix_nano` / `end_time_unix_nano` / `duration_nano` | bigints |
| `service_name` | from resource attributes |
| `resource_attributes` / `span_attributes` / `events` | JSON |
| `session_id` (computed) | pulled from `traceloop.association.properties.session.id` |
| `app_type` / `app_name` / `app_id` (computed) | for cross-service lookups |
| `status_code` / `status_message` | `Unset` / `Ok` / `Error` |

Roots: `parent_span_id = ''`. Not NULL. Queries that check `IS NULL` will
miss them.

## otel_logs

| column | notes |
| --- | --- |
| `time` | bigint ns since epoch |
| `trace_id` / `span_id` | hex strings, or `''`/`0x0` if log emitted outside any span |
| `severity_text` | `DEBUG` `INFO` `WARN` `ERROR` (Python `WARNING` normalizes to `WARN`) |
| `scope_name` | Python logger name, e.g. `observability_v2.streaming`, `singlestore_ai.v1`, `httpx` |
| `body` | longtext — can be hundreds of chars; truncate in display |
| `log_attributes` / `resource_attributes` / `scope_attributes` | JSON |

Log-to-span association happens at emit time — the OTel `LoggingHandler`
reads `get_current_span().get_span_context()` when `logger.info(...)`
fires. If no span is active at that moment, `span_id` is zero and the log
attaches to no span in the /traces UI.

## Queries you'll reach for

### Span tree for a trace

```sql
SELECT span_id, parent_span_id, span_name, span_kind,
       start_time_unix_nano, duration_nano, status_code
FROM otel_traces
WHERE trace_id = '<tid>'
ORDER BY start_time_unix_nano;
```

Build the parent/child tree client-side. `scripts/pulse.py trace <tid>`
does this.

### Logs for one span

```sql
SELECT time, severity_text, scope_name, body
FROM otel_logs
WHERE span_id = '<sid>'
ORDER BY time
LIMIT 100;
```

### Log count per span (log attachment diagnostic)

```sql
SELECT l.span_id, t.span_name, COUNT(*) AS n
FROM otel_logs l
LEFT JOIN otel_traces t
  ON l.trace_id = t.trace_id AND l.span_id = t.span_id
WHERE l.trace_id = '<tid>'
GROUP BY l.span_id, t.span_name
ORDER BY n DESC;
```

If one span has all the logs (usually the root), instrumentation isn't
calling `start_as_current_span` around child work — spans exist in the
tree but never become the current context, so log emission binds to the
ancestor that is current. This is the `attachment` subcommand.

### Filtered log tail

```sql
SELECT time, severity_text, scope_name, span_id, body
FROM otel_logs
WHERE trace_id = '<tid>'
  AND scope_name LIKE '%observability_v2%'
ORDER BY time DESC
LIMIT 100;
```

Swap `scope_name LIKE` for `body LIKE` to grep log bodies.

### Find a trace from a session id

```sql
SELECT DISTINCT trace_id, span_name, start_time_unix_nano
FROM otel_traces
WHERE session_id = '<sid>' AND parent_span_id = ''
ORDER BY start_time_unix_nano DESC
LIMIT 10;
```

`session_id` is a computed column; same approach works for `app_id`,
`org_id`, etc. when you know those but not the trace_id.

### Does this trace have errors?

```sql
SELECT span_id, span_name, status_code, status_message
FROM otel_traces
WHERE trace_id = '<tid>' AND status_code = 'Error';
```

## Gotchas

- **Per-workspace instances.** Pulse has a separate SingleStore workspace
  per customer/project. A trace_id is only unique within one workspace.
  Always connect to the workspace the user points at.
- **`time` is bigint nanoseconds.** Convert with `FROM_UNIXTIME(time / 1e9)`
  if you want a human date, but careful — the implicit cast to double
  loses nanosecond precision.
- **No `mysql` CLI locally.** Use `singlestoredb` via Python. The helper
  script handles this.
- **Log bodies can be JSON, Python reprs, or prose.** Don't try to parse
  them structurally unless you've sampled a few and know the shape.
