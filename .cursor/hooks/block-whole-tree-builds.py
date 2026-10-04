#!/usr/bin/env python3
"""Refuse whole-tree builds and test runs so agents scope them to what they touched.

Blocks:
  - go build/test/vet with ./..., ..., or all
  - Cypress runs (cypress run, cct:run) that are not a targeted --spec run:
    no --spec, --spec after a bare `--` (Cypress then ignores it and runs every
    spec), a whole-tree glob, or `npm exec cypress` (npm takes the flags)

Only real invocations count, not text: `echo go build ./...` or a commit
message mentioning it is allowed. Nested `bash -c '...'` scripts are scanned.

Works as a Cursor hook (JSON on stdout) and a Claude Code PreToolUse hook
(exit 2 + stderr). Cursor also runs ~/.claude/settings.json hooks, with
cursor_version set; those get Cursor's format so the reason shows.
"""

import json
import re
import shlex
import sys

CYPRESS_HOWTO = (
    "Run only the specs you touched, from the worktree root:\n"
    "  direnv exec . bash -c 'cd frontend && pnpm run cct:run --spec src/pages/path/to/file.spec.tsx'\n"
    "cct:run adds --spec to its own setup (msw init, NODE_ENV=test, Chrome). Several specs: "
    "--spec a.spec.tsx,b.spec.tsx. Never put a bare `--` before --spec, and never use `npm exec cypress`."
)
GO_HOWTO = (
    "Build and test only the packages you touched, from the worktree root:\n"
    "  direnv exec . bash -c 'cd singlestore.com/helios && go test -p 2 ./billing/analystbudget/ ./graph/server/public/ -run TestName'\n"
    "Use pkg/... only for a package you changed and its subpackages, and go build -p 2 / go vet the same way."
)
WRAPPERS = {"exec", "time", "env", "nice", "nohup", "command", "builtin"}


OPERATORS = {"&&", "||", ";", "|", "&", "(", ")", ";;", "|&", "\n"}


def segments(text):
    """Split shell text into simple commands, keeping quoted strings whole.
    Unquoted newlines separate commands; quoted ones stay in their token."""
    try:
        lex = shlex.shlex(text, posix=True, punctuation_chars=";&|()\n")
        lex.whitespace = " \t\r"
        lex.whitespace_split = True
        toks = list(lex)
    except ValueError:
        toks = text.split()
    current = []
    for t in toks:
        if t in OPERATORS:
            if current:
                yield current
            current = []
        else:
            current.append(t)
    if current:
        yield current


def strip_prefix(toks):
    """Drop env assignments and wrappers (direnv exec DIR, nice -n N, ...)."""
    i = 0
    while i < len(toks):
        t = toks[i]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", t):
            i += 1
        elif t == "direnv" and i + 2 < len(toks) and toks[i + 1] == "exec":
            i += 3
        elif t == "nice" and i + 1 < len(toks) and toks[i + 1] == "-n":
            i += 3
        elif t in WRAPPERS:
            i += 1
        else:
            break
    return toks[i:]


def spec_problem(args):
    """args: everything after `cypress run` (or after the cct:run script name)."""
    if "--" in args:
        dash = args.index("--")
        if any(a == "--spec" or a.startswith("--spec=") for a in args[dash + 1 :]):
            return (
                "A bare `--` before --spec ends option parsing, so Cypress ignores --spec "
                f"and runs every spec.\n{CYPRESS_HOWTO}"
            )
    specs = []
    for i, a in enumerate(args):
        if a == "--spec" and i + 1 < len(args):
            specs.append(args[i + 1])
        elif a.startswith("--spec="):
            specs.append(a.split("=", 1)[1])
    if not specs:
        return f"Full Cypress runs are blocked; this one has no --spec.\n{CYPRESS_HOWTO}"
    for s in specs:
        for part in s.split(","):
            if re.match(r"^(\./)?((src|cypress)/)?\*\*", part.strip()):
                return f"`--spec {s}` matches the whole tree, so it is a full run.\n{CYPRESS_HOWTO}"
    return None


def check(toks):
    toks = strip_prefix(toks)
    if not toks:
        return None
    head = toks[0].rsplit("/", 1)[-1]

    if head == "go" and len(toks) > 1 and toks[1] in ("build", "test", "vet"):
        if any(a in ("./...", "...", "all") for a in toks[2:]):
            return f"Whole-module Go builds and tests (./..., all) are blocked.\n{GO_HOWTO}"

    if head == "npm" and len(toks) > 2 and toks[1] == "exec" and toks[2].rsplit("/", 1)[-1] == "cypress":
        return f"`npm exec cypress` hands Cypress's flags to npm instead.\n{CYPRESS_HOWTO}"

    if head in ("pnpm", "npm", "yarn"):
        rest = toks[1:]
        if rest and rest[0] == "run":
            rest = rest[1:]
        if rest and rest[0] == "cct:run":
            return spec_problem(rest[1:])

    i = 0
    if head in ("npx", "pnpm", "yarn"):
        i = 1
        while i < len(toks) and (toks[i] in ("exec", "dlx", "--") or toks[i].startswith("-")):
            i += 1
    if i + 1 < len(toks) and toks[i].rsplit("/", 1)[-1] == "cypress" and toks[i + 1] == "run":
        return spec_problem(toks[i + 2 :])
    return None


HEREDOC = re.compile(r"<<-?\s*(['\"]?)(\w+)\1[^\n]*\n.*?^\s*\2\s*$", re.S | re.M)


def nested_script(toks):
    """The script of `bash -c '...'`, `sh -c`, `zsh -c`, or `eval ...`, if any."""
    toks = strip_prefix(toks)
    if not toks:
        return None
    head = toks[0].rsplit("/", 1)[-1]
    if head in ("bash", "sh", "zsh") and "-c" in toks[1:-1]:
        return toks[toks.index("-c", 1) + 1]
    if head == "eval":
        return " ".join(toks[1:])
    return None


def scan(text, depth=0):
    text = HEREDOC.sub(lambda m: m.group(0).split("\n", 1)[0], text)
    for toks in segments(text):
        problem = check(toks)
        if problem:
            return problem
        script = nested_script(toks)
        if script and depth < 3:
            problem = scan(script, depth + 1)
            if problem:
                return problem
    return None


def main():
    data = json.load(sys.stdin)
    command = data.get("command") or (data.get("tool_input") or {}).get("command") or ""
    cursor = "cursor_version" in data or "tool_input" not in data
    problem = scan(command)

    if not problem:
        if cursor:
            print(json.dumps({"continue": True, "permission": "allow"}))
        return 0
    if not cursor:
        print(f"BLOCKED: {problem}", file=sys.stderr)
        return 2
    print(
        json.dumps(
            {
                "continue": True,
                "permission": "deny",
                "user_message": f"Blocked by hook: {problem}",
                "agent_message": f"BLOCKED: {problem}",
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
