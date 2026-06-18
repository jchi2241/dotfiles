#!/usr/bin/env python3
"""pulse.py — fetch traces and logs from the Pulse SingleStore backend.

Pulse is our OTel trace/log store; this script is the CLI-speed shortcut
so Claude doesn't keep re-inventing ad-hoc SQL.

Connection info is sourced from env vars:
    PULSE_HOST      (required)
    PULSE_PORT      (default 3306)
    PULSE_USER      (default admin)
    PULSE_PASSWORD  (required)
    PULSE_DB        (default pulse)

Override via --host, --user, --password at call time.

Subcommands:
    trace <trace_id>           span tree + log-count-per-span + log tail
    span <span_id>             logs attached to one span (with span info)
    logs --trace <tid> [...]   filtered log tail (--grep, --scope, --limit)
    attachment <trace_id>      histogram of which span each log attached to

All output is human-readable by default. Pass --json on the top-level
command for machine-parseable output (useful when the trace has hundreds
of spans and you want to grep).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import textwrap
from typing import Any

try:
    import singlestoredb as s2
except ImportError:
    sys.stderr.write(
        "singlestoredb not available. Invoke via:\n"
        "  /home/jchi/projects/singlestore-ai/.venv/bin/python "
        f"{sys.argv[0]} ...\n"
    )
    sys.exit(2)


DEFAULT_BODY_TRUNC = 200
DEFAULT_LIMIT = 100


def connect(args: argparse.Namespace):
    host = args.host or os.environ.get("PULSE_HOST")
    user = args.user or os.environ.get("PULSE_USER", "admin")
    password = args.password or os.environ.get("PULSE_PASSWORD")
    port = int(args.port or os.environ.get("PULSE_PORT", "3306"))
    db = args.db or os.environ.get("PULSE_DB", "pulse")

    missing = [n for n, v in (("PULSE_HOST", host), ("PULSE_PASSWORD", password)) if not v]
    if missing:
        sys.stderr.write(
            f"missing connection info: {', '.join(missing)}\n"
            "set env vars or pass --host/--password.\n"
        )
        sys.exit(2)

    return s2.connect(host=host, port=port, user=user, password=password, database=db)


def truncate(s: str | None, n: int = DEFAULT_BODY_TRUNC, full: bool = False) -> str:
    if s is None:
        return ""
    if full or len(s) <= n:
        return s
    return f"{s[:n]}... ({len(s) - n} more chars)"


def fmt_duration(ns: int | None) -> str:
    if ns is None:
        return "?"
    if ns < 1_000:
        return f"{ns}ns"
    if ns < 1_000_000:
        return f"{ns / 1_000:.1f}µs"
    if ns < 1_000_000_000:
        return f"{ns / 1_000_000:.1f}ms"
    return f"{ns / 1_000_000_000:.2f}s"


# -----------------------------------------------------------------------------
# trace <trace_id>
# -----------------------------------------------------------------------------

def cmd_trace(args: argparse.Namespace) -> int:
    conn = connect(args)
    cur = conn.cursor()

    # Fetch all spans + log counts in two queries.
    cur.execute(
        """
        SELECT span_id, parent_span_id, span_name, span_kind,
               start_time_unix_nano, duration_nano, status_code, service_name
        FROM otel_traces
        WHERE trace_id = %s
        ORDER BY start_time_unix_nano
        """,
        (args.trace_id,),
    )
    span_rows = cur.fetchall()
    if not span_rows:
        print(f"no spans found for trace_id={args.trace_id!r}")
        return 1

    spans: dict[str, dict[str, Any]] = {}
    roots: list[str] = []
    for sid, pid, name, kind, start_ns, dur_ns, status, svc in span_rows:
        spans[sid] = {
            "span_id": sid,
            "parent_span_id": pid or None,
            "name": name,
            "kind": kind,
            "start_time_unix_nano": int(start_ns) if start_ns is not None else None,
            "duration_nano": int(dur_ns) if dur_ns is not None else None,
            "status": status,
            "service_name": svc,
            "children": [],
            "log_count": 0,
        }
    for sid, sp in spans.items():
        pid = sp["parent_span_id"]
        if pid and pid in spans:
            spans[pid]["children"].append(sid)
        else:
            roots.append(sid)

    cur.execute(
        """
        SELECT span_id, COUNT(*) as n
        FROM otel_logs
        WHERE trace_id = %s
        GROUP BY span_id
        """,
        (args.trace_id,),
    )
    for sid, n in cur.fetchall():
        if sid in spans:
            spans[sid]["log_count"] = int(n)

    cur.execute(
        """
        SELECT time, severity_text, scope_name, span_id, body
        FROM otel_logs
        WHERE trace_id = %s
        ORDER BY time DESC
        LIMIT %s
        """,
        (args.trace_id, args.limit),
    )
    log_tail = [
        {
            "time": int(t) if t is not None else None,
            "severity": sev,
            "scope": scope,
            "span_id": sid,
            "body": body,
        }
        for t, sev, scope, sid, body in cur.fetchall()
    ]

    if args.json:
        print(json.dumps(
            {
                "trace_id": args.trace_id,
                "spans": list(spans.values()),
                "roots": roots,
                "log_tail": log_tail,
            },
            indent=2,
            default=str,
        ))
        return 0

    # Pretty tree.
    total_logs = sum(sp["log_count"] for sp in spans.values())
    print(f"trace {args.trace_id}: {len(spans)} spans, {total_logs} logs")
    print()

    def walk(sid: str, depth: int):
        sp = spans[sid]
        indent = "  " * depth
        log_marker = f" [{sp['log_count']} logs]" if sp["log_count"] else ""
        print(
            f"{indent}{sp['span_id']}  {sp['name']} "
            f"({sp['kind']}, {fmt_duration(sp['duration_nano'])}){log_marker}"
        )
        for child in sorted(sp["children"], key=lambda c: spans[c]["start_time_unix_nano"] or 0):
            walk(child, depth + 1)

    for root_sid in roots:
        walk(root_sid, 0)

    print()
    print(f"last {len(log_tail)} logs (newest first):")
    for log in reversed(log_tail):
        sid_short = (log["span_id"] or "")[:8] or "<none>"
        body = truncate(log["body"], n=args.body_chars, full=args.full)
        print(f"  [{log['severity']}] span={sid_short} {log['scope']}: {body}")

    return 0


# -----------------------------------------------------------------------------
# span <span_id>
# -----------------------------------------------------------------------------

def cmd_span(args: argparse.Namespace) -> int:
    conn = connect(args)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT trace_id, parent_span_id, span_name, span_kind,
               start_time_unix_nano, duration_nano, status_code, service_name,
               span_attributes
        FROM otel_traces
        WHERE span_id = %s
        LIMIT 1
        """,
        (args.span_id,),
    )
    row = cur.fetchone()
    if not row:
        print(f"no span found for span_id={args.span_id!r}")
        return 1
    trace_id, parent, name, kind, start_ns, dur_ns, status, svc, attrs = row

    cur.execute(
        """
        SELECT time, severity_text, scope_name, body
        FROM otel_logs
        WHERE span_id = %s
        ORDER BY time
        LIMIT %s
        """,
        (args.span_id, args.limit),
    )
    logs = [
        {"time": int(t) if t is not None else None, "severity": sev, "scope": scope, "body": body}
        for t, sev, scope, body in cur.fetchall()
    ]

    if args.json:
        print(json.dumps(
            {
                "span": {
                    "span_id": args.span_id,
                    "trace_id": trace_id,
                    "parent_span_id": parent,
                    "name": name,
                    "kind": kind,
                    "start_time_unix_nano": int(start_ns) if start_ns is not None else None,
                    "duration_nano": int(dur_ns) if dur_ns is not None else None,
                    "status": status,
                    "service_name": svc,
                    "attributes": attrs,
                },
                "logs": logs,
            },
            indent=2,
            default=str,
        ))
        return 0

    print(f"span {args.span_id}  trace={trace_id}  parent={parent or '<none>'}")
    print(f"  name={name!r}  kind={kind}  dur={fmt_duration(int(dur_ns) if dur_ns else None)}")
    print(f"  service={svc}  status={status}")
    print()
    print(f"{len(logs)} log(s):")
    for log in logs:
        body = truncate(log["body"], n=args.body_chars, full=args.full)
        print(f"  [{log['severity']}] {log['scope']}: {body}")
    return 0


# -----------------------------------------------------------------------------
# logs (filtered tail)
# -----------------------------------------------------------------------------

def cmd_logs(args: argparse.Namespace) -> int:
    conn = connect(args)
    cur = conn.cursor()

    where: list[str] = []
    params: list[Any] = []
    if args.trace:
        where.append("trace_id = %s")
        params.append(args.trace)
    if args.span:
        where.append("span_id = %s")
        params.append(args.span)
    if args.scope:
        where.append("scope_name LIKE %s")
        params.append(f"%{args.scope}%")
    if args.grep:
        where.append("body LIKE %s")
        params.append(f"%{args.grep}%")
    if args.severity:
        where.append("severity_text = %s")
        params.append(args.severity.upper())

    if not where:
        sys.stderr.write("logs: supply at least one filter (--trace, --span, --scope, --grep, --severity)\n")
        return 2

    sql = (
        "SELECT time, severity_text, scope_name, trace_id, span_id, body "
        "FROM otel_logs WHERE " + " AND ".join(where) + " ORDER BY time DESC LIMIT %s"
    )
    params.append(args.limit)
    cur.execute(sql, tuple(params))
    rows = cur.fetchall()

    if args.json:
        print(json.dumps(
            [
                {
                    "time": int(t) if t is not None else None,
                    "severity": sev,
                    "scope": scope,
                    "trace_id": tid,
                    "span_id": sid,
                    "body": body,
                }
                for t, sev, scope, tid, sid, body in rows
            ],
            indent=2,
            default=str,
        ))
        return 0

    # Show oldest→newest so tail reads naturally.
    for t, sev, scope, tid, sid, body in reversed(rows):
        sid_short = (sid or "")[:8] or "<none>"
        tid_short = (tid or "")[:8] or "<none>"
        body_s = truncate(body, n=args.body_chars, full=args.full)
        print(f"[{sev}] trace={tid_short} span={sid_short} {scope}: {body_s}")
    return 0


# -----------------------------------------------------------------------------
# attachment (diagnostic: where are the logs landing?)
# -----------------------------------------------------------------------------

def cmd_attachment(args: argparse.Namespace) -> int:
    conn = connect(args)
    cur = conn.cursor()

    cur.execute(
        """
        SELECT l.span_id, t.span_name, COUNT(*) as n_logs
        FROM otel_logs l
        LEFT JOIN otel_traces t
            ON l.trace_id = t.trace_id AND l.span_id = t.span_id
        WHERE l.trace_id = %s
        GROUP BY l.span_id, t.span_name
        ORDER BY n_logs DESC
        """,
        (args.trace_id,),
    )
    rows = cur.fetchall()
    if not rows:
        print(f"no logs for trace {args.trace_id}")
        return 1

    total = sum(int(n) for _, _, n in rows)
    if args.json:
        print(json.dumps(
            {
                "trace_id": args.trace_id,
                "total_logs": total,
                "distribution": [
                    {"span_id": sid, "span_name": name, "n_logs": int(n)}
                    for sid, name, n in rows
                ],
            },
            indent=2,
        ))
        return 0

    print(f"trace {args.trace_id}: {total} logs across {len(rows)} span(s)")
    for sid, name, n in rows:
        pct = 100 * int(n) / total if total else 0
        name_s = name or "<no matching span>"
        print(f"  {int(n):5d} ({pct:5.1f}%)  span={sid}  {name_s}")
    return 0


# -----------------------------------------------------------------------------
# argparse scaffolding
# -----------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Query the Pulse OTel store (SingleStore).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent(
            """\
            Env vars: PULSE_HOST, PULSE_PORT, PULSE_USER, PULSE_PASSWORD, PULSE_DB.
            Run under the singlestoredb-equipped python, e.g.:
              /home/jchi/projects/singlestore-ai/.venv/bin/python <this> ...
            """
        ),
    )
    p.add_argument("--host")
    p.add_argument("--port")
    p.add_argument("--user")
    p.add_argument("--password")
    p.add_argument("--db")
    p.add_argument("--json", action="store_true", help="machine-readable output")
    p.add_argument(
        "--body-chars", type=int, default=DEFAULT_BODY_TRUNC,
        help=f"log body truncation (default {DEFAULT_BODY_TRUNC}); --full overrides",
    )
    p.add_argument("--full", action="store_true", help="don't truncate log bodies")

    sub = p.add_subparsers(dest="cmd", required=True)

    t = sub.add_parser("trace", help="span tree + log counts + tail")
    t.add_argument("trace_id")
    t.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    t.set_defaults(func=cmd_trace)

    s = sub.add_parser("span", help="one span + its logs")
    s.add_argument("span_id")
    s.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    s.set_defaults(func=cmd_span)

    lg = sub.add_parser("logs", help="filtered log tail")
    lg.add_argument("--trace")
    lg.add_argument("--span")
    lg.add_argument("--scope", help="scope_name substring (e.g. observability_v2)")
    lg.add_argument("--grep", help="body substring")
    lg.add_argument("--severity", help="exact severity (INFO, WARN, ERROR)")
    lg.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    lg.set_defaults(func=cmd_logs)

    at = sub.add_parser("attachment", help="which spans did logs attach to?")
    at.add_argument("trace_id")
    at.set_defaults(func=cmd_attachment)

    return p


def main() -> int:
    args = build_parser().parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
