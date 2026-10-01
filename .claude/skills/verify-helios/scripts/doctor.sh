#!/usr/bin/env bash
# Read-only health check for the local Helios + Analyst stack.
# Usage: doctor.sh [--no-portal]
# Exits 1 if any check fails.

set -uo pipefail

HELIOS="${HELIOS:-$HOME/projects/helios}"
CHECK_PORTAL=1
[[ "${1:-}" == "--no-portal" ]] && CHECK_PORTAL=0

failures=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }

k() { direnv exec "$HELIOS" kubectl "$@" 2>/dev/null; }

if k get --raw /readyz >/dev/null; then
	pass "k3d API server answers"
else
	fail "k3d API server unreachable. Run: K3D_FIX_DNS=0 k3d cluster start helios-infra-local-dev"
	exit 1
fi

check_deploy() {
	local ns="$1" name="$2" ready
	ready=$(k get deploy -n "$ns" "$name" -o jsonpath='{.status.readyReplicas}/{.spec.replicas}')
	if [[ -n "$ready" && "${ready%/*}" == "${ready#*/}" && "${ready%/*}" != "0" ]]; then
		pass "$ns/$name ready ($ready)"
	else
		local reason
		reason=$(k get pods -n "$ns" --no-headers 2>/dev/null | awk -v n="$name" 'index($1, n) == 1 {print $3; exit}')
		fail "$ns/$name not ready (${ready:-missing}, pod: ${reason:-none})"
	fi
}

for d in heliospg statesvc authsvc; do check_deploy default "$d"; done
for d in nova-gateway-deployment aura-context-service unified-model-gateway-deployment; do check_deploy fission "$d"; done

check_http() {
	local label="$1" url="$2" want="$3" code
	code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url")
	if [[ "$code" =~ $want ]]; then pass "$label ($url -> $code)"; else fail "$label ($url -> ${code:-no answer})"; fi
}

check_http "statesvc GraphQL" "http://localhost:9001/public" '^(200|400|401|405)$'
check_http "authsvc answers" "http://localhost:9002/auth" '^[1-5][0-9][0-9]$'

if [[ "$(curl -s --max-time 5 http://localhost:8000/health)" == "ok" ]]; then
	pass "nova-gateway /health (localhost:8000)"
else
	fail "nova-gateway /health did not return ok (localhost:8000)"
fi

if [[ "$(k get --raw /api/v1/namespaces/fission/services/http:aura-context-svc:8080/proxy/health)" == *healthy* ]]; then
	pass "aura-context /health"
else
	fail "aura-context /health not healthy"
fi

sqlbot=$(k get pods -n fission -l app.kubernetes.io/managed-by=nova --no-headers | awk '$3 == "Running" {n++} END {print n + 0}')
if [[ "$sqlbot" -gt 0 ]]; then
	pass "nova containers running in fission ($sqlbot)"
else
	printf 'INFO  no nova containers running yet. The first chat turn starts one and can take a minute.\n'
fi

if [[ "$CHECK_PORTAL" == 1 ]]; then
	pid=$(ss -ltnpH 'sport = :8001' 2>/dev/null | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | head -1)
	if [[ -z "$pid" ]]; then
		fail "nothing listens on :8001. Run: direnv exec $HELIOS make frontend-start"
	else
		cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null || echo unknown)
		if [[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:8001/)" == 200 ]]; then
			pass "portal :8001 serves (pid $pid, cwd $cwd)"
		else
			fail "portal :8001 does not answer 200 (pid $pid, cwd $cwd)"
		fi
		if pgrep -af 'PORTAL_LOCAL_MOCKED=true' >/dev/null || tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | grep -q '^PORTAL_LOCAL_MOCKED=true'; then
			fail "portal :8001 is the mocked frontend. Real-backend verification needs make frontend-start"
		fi
	fi
fi

if [[ "$failures" -gt 0 ]]; then
	printf '\n%d check(s) failed.\n' "$failures"
	exit 1
fi
printf '\nStack is worth driving.\n'
