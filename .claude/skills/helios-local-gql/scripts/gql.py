#!/usr/bin/env python3
"""Call the Helios localdev private GraphQL API (statesvc) with a System JWT.

Delegates JWT generation to the canonical helios helper so this never forks
secret-handling logic:
    $HELIOS_REPO/local-dev-utilities/get_private_auth_header.sh
      -> prints "Bearer <jwt>"

Dependencies: requests + stdlib. The helper needs pyjwt in the user's env and a
populated test/realm-secrets.json (normally set up by `make kube-init`).

Usage:
    gql.py --query '{ __typename }'
    gql.py --query-file ./q.gql --variables '{"projectID":"..."}'
    cat q.gql | gql.py --operation MyOp
    gql.py --endpoint http://127.0.0.1:9001/private --query '...'    # override URL
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Optional

import requests

DEFAULT_ENDPOINT = "http://127.0.0.1:9001/private"

HELIOS_REPO_CANDIDATES = (
    os.environ.get("HELIOS_REPO"),
    os.path.expanduser("~/projects/helios"),
    "/home/jchi/projects/helios",
)


def resolve_helios_repo(override: Optional[str]) -> Path:
    candidates = [override, *HELIOS_REPO_CANDIDATES]
    for c in candidates:
        if not c:
            continue
        p = Path(c).expanduser()
        if (p / "local-dev-utilities" / "get_private_auth_header.sh").is_file():
            return p
    tried = [c for c in candidates if c]
    raise SystemExit(
        "Could not locate the helios repo. Set HELIOS_REPO or pass --helios-repo.\n"
        f"Tried: {tried}"
    )


def get_private_auth_header(helios_repo: Path) -> str:
    script = helios_repo / "local-dev-utilities" / "get_private_auth_header.sh"
    try:
        out = subprocess.run(
            ["bash", str(script)],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as e:
        raise SystemExit(
            "Failed to generate System JWT via get_private_auth_header.sh.\n"
            f"stderr: {e.stderr.strip()}\n"
            "Hints: ensure `pyjwt` (and `cryptography` for RS/ES keys) is installed, "
            "and that the local helios backend has been initialized (`make kube-init`)."
        )
    header = out.stdout.strip().splitlines()[-1].strip() if out.stdout.strip() else ""
    if not header.startswith("Bearer "):
        raise SystemExit(f"Unexpected auth header from helper: {header!r}")
    return header


def read_query(args: argparse.Namespace) -> str:
    if args.query is not None:
        return args.query
    if args.query_file:
        if args.query_file == "-":
            return sys.stdin.read()
        return Path(args.query_file).read_text(encoding="utf-8")
    if not sys.stdin.isatty():
        return sys.stdin.read()
    raise SystemExit("Provide --query, --query-file, or pipe the query via stdin.")


def parse_variables(var_str: Optional[str]) -> Optional[dict]:
    if not var_str:
        return None
    try:
        obj = json.loads(var_str)
    except json.JSONDecodeError as e:
        raise SystemExit(f"Invalid JSON for --variables: {e}")
    if obj is None:
        return None
    if not isinstance(obj, dict):
        raise SystemExit("--variables must be a JSON object")
    return obj


def post_with_retries(
    url: str,
    body: dict,
    headers: dict,
    retries: int,
    backoff: float,
) -> requests.Response:
    attempt = 0
    while True:
        try:
            resp = requests.post(url, json=body, headers=headers, timeout=30)
        except (requests.ConnectionError, requests.Timeout) as e:
            if attempt >= retries:
                raise SystemExit(
                    f"Request to {url} failed after {attempt} retries: {e}\n"
                    "Hints: is statesvc up on 127.0.0.1:9001? "
                    "Did `make kube-init` finish?"
                )
            time.sleep(backoff * (2**attempt))
            attempt += 1
            continue
        if resp.status_code == 104 and attempt < retries:
            time.sleep(backoff * (2**attempt))
            attempt += 1
            continue
        return resp


def main() -> int:
    p = argparse.ArgumentParser(
        description="Call the Helios localdev private GraphQL API.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    p.add_argument("--endpoint", default=DEFAULT_ENDPOINT, help="Override the default URL.")
    p.add_argument("--query", help="Inline query string")
    p.add_argument("--query-file", help="Path to .gql file, or '-' for stdin")
    p.add_argument("--operation", help="operationName")
    p.add_argument("--variables", help='JSON object, e.g. \'{"id":"abc"}\'')
    p.add_argument("--helios-repo", help="Path to helios repo (for auth helper)")
    p.add_argument("--retries", type=int, default=5)
    p.add_argument("--backoff", type=float, default=0.2)
    p.add_argument("--raw", action="store_true", help="Print raw body instead of pretty JSON.")
    p.add_argument(
        "--no-fail-on-errors",
        action="store_true",
        help="Exit 0 even when the GraphQL response contains an 'errors' field.",
    )
    args = p.parse_args()

    query = read_query(args)
    variables = parse_variables(args.variables)

    body: dict[str, Any] = {"query": query}
    if args.operation:
        body["operationName"] = args.operation
    if variables:
        body["variables"] = variables

    helios_repo = resolve_helios_repo(args.helios_repo)
    headers = {
        "Content-Type": "application/json",
        "Authorization": get_private_auth_header(helios_repo),
        "X-Client-Id": "helios-local-gql-skill",
    }

    resp = post_with_retries(args.endpoint, body, headers, args.retries, args.backoff)

    payload = None
    if args.raw:
        sys.stdout.write(resp.text)
        sys.stdout.write("\n")
    else:
        try:
            payload = resp.json()
            print(json.dumps(payload, indent=2, sort_keys=True))
        except ValueError:
            sys.stdout.write(resp.text)
            sys.stdout.write("\n")
            return 1 if resp.status_code >= 400 else 0

    if resp.status_code == 401:
        print(
            "\n[hint] 401: the System JWT was rejected. Check that statesvc is up "
            "and test/realm-secrets.json matches the deployed keys. JWTs have a "
            "1-hour TTL, so just rerunning usually works.",
            file=sys.stderr,
        )
        return 1
    if resp.status_code >= 400:
        return 1
    if not args.no_fail_on_errors and isinstance(payload, dict) and payload.get("errors"):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
