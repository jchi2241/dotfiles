#!/usr/bin/env bash
# Collect per-hop log evidence for one Analyst chat turn.
# Usage: hop-evidence.sh <session_id> <evidence_dir> <since_rfc3339>
# Writes <evidence_dir>/logs/<hop>.log and prints one PASS/FAIL line per hop.
# Exits 1 if a required hop shows no sign of the turn.

set -uo pipefail

SID="${1:?session id}"
OUT="${2:?evidence dir}"
SINCE="${3:?since time, e.g. 2026-10-01T08:00:00Z}"
HELIOS="${HELIOS:-$HOME/projects/helios}"

mkdir -p "$OUT/logs"
failures=0
k() { direnv exec "$HELIOS" kubectl "$@" 2>/dev/null; }

logs() {
	local ns="$1" selector="$2" file="$3"
	k logs -n "$ns" -l "$selector" --since-time="$SINCE" --tail=-1 --prefix --max-log-requests=20 >"$OUT/logs/$file"
}

hop() {
	local label="$1" file="$2" pattern="$3" required="$4" hits
	hits=$(grep -cE -- "$pattern" "$OUT/logs/$file" || true)
	if [[ "$hits" -gt 0 ]]; then
		printf 'PASS  %-14s %s match(es) for /%s/ in logs/%s\n' "$label" "$hits" "$pattern" "$file"
	elif [[ "$required" == required ]]; then
		printf 'FAIL  %-14s no match for /%s/ in logs/%s\n' "$label" "$pattern" "$file"
		failures=$((failures + 1))
	else
		printf 'INFO  %-14s no match for /%s/ in logs/%s\n' "$label" "$pattern" "$file"
	fi
}

logs fission app.kubernetes.io/component=nova-gateway nova-gateway.log
logs fission app.kubernetes.io/component=aura-context-service aura-context.log
logs fission app.kubernetes.io/component=unified-model-gateway umg.log
# sqlbot prints nothing to stdout per turn and its pods churn; kept only for post-mortems.
logs default app.kubernetes.io/managed-by=nova sqlbot.log

hop nova-gateway nova-gateway.log "Session created/updated: $SID" required
hop aura-context aura-context.log "$SID" optional
hop sqlbot nova-gateway.log "container URL: http://heliosnotebook-" required
hop umg umg.log "adjusted path after project ID extraction: /v1/model/claude[^ \"]*/(converse|invoke)" required

if grep -qiE 'level=error|"level":"error"|panic' "$OUT/logs/nova-gateway.log" "$OUT/logs/umg.log" 2>/dev/null; then
	printf 'INFO  errors logged during the window; read logs/nova-gateway.log and logs/umg.log\n'
fi

[[ "$failures" -gt 0 ]] && exit 1
exit 0
