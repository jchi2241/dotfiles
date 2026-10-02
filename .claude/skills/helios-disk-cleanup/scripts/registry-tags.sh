#!/usr/bin/env bash
# Audit or prune old tags in the local k3d registry (k3d-registry.localhost).
# Tilt pushes a new content-hash tag (tilt-<hash>) on every rebuild and the
# registry never deletes, so old tags and their layers pile up.
#
# Usage (run via `direnv exec ~/projects/helios` so kubectl has the kubeconfig):
#   registry-tags.sh            # read-only audit: TSV of every tag with a verdict
#   registry-tags.sh --apply    # delete DELETE rows, garbage-collect, restart registry
# Env: KEEP_NEWEST (default 3 per repo), KEEP_DAYS (default 3).
#
# A tag is deleted only if all hold: no pod in the cluster uses its tag or
# digest, no worktree's tracked files mention it, it is not among the newest
# KEEP_NEWEST tags of its repo, and it was pushed more than KEEP_DAYS ago.
set -euo pipefail

registry=k3d-registry.localhost
root=/var/lib/registry/docker/registry/v2/repositories
helios="$HOME/projects/helios"
keep_newest="${KEEP_NEWEST:-3}"
keep_days="${KEEP_DAYS:-3}"
apply=no
[ "${1:-}" = --apply ] && apply=yes

die() { echo "error: $*" >&2; exit 1; }

[ "$(docker inspect -f '{{.State.Running}}' "$registry" 2>/dev/null)" = true ] \
	|| die "$registry is not running"

# Without a running cluster we cannot prove a tag is unused.
[ -n "$(docker ps -q --filter label=k3d.role=server)" ] \
	|| die "no k3d cluster is running; start it so in-use images can be checked"
[[ $(kubectl config current-context) == k3d-* ]] \
	|| die "kube context $(kubectl config current-context) is not a k3d cluster"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Every image ref and digest any pod uses, including pending and init containers.
kubectl get pods -A -o json | jq -r '
	.items[] | ((.spec.containers + (.spec.initContainers // []))[].image),
	(((.status.containerStatuses // []) + (.status.initContainerStatuses // []))[]
		| .image, .imageID)' | grep -F "$registry" | sort -u > "$work/in-use" \
	|| die "no pod uses an image from $registry (Helios not deployed yet?); cannot prove which tags are unused"

# repo <TAB> tag <TAB> pushed-epoch <TAB> digest, one row per tag.
docker exec "$registry" sh -c "cd $root && find . -path '*/_manifests/tags/*/current/link'" \
	| sed 's#^\./##; s#/_manifests/tags/# #; s#/current/link$##' > "$work/repo-tag"
docker exec -i "$registry" sh -c "cd $root && while read r t; do
	printf '%s\t%s\t%s\t%s\n' \"\$r\" \"\$t\" \"\$(stat -c %Y \"\$r/_manifests/tags/\$t/current/link\")\" \
		\"\$(cat \"\$r/_manifests/tags/\$t/current/link\")\"
done" < "$work/repo-tag" | sort -t$'\t' -k1,1 -k3,3nr > "$work/tags"

# Tags mentioned in any worktree's tracked files (pinned versions, test fixtures).
cut -f2 "$work/tags" | sort -u > "$work/tag-names"
git -C "$helios" worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r wt; do
	# GNU grep handles ~1000 literal patterns in under a second; git grep takes minutes.
	[ -d "$wt" ] && (cd "$wt" && git ls-files -z | xargs -0 grep -hoIF -f "$work/tag-names" 2>/dev/null) || true
done | sort -u > "$work/referenced"

cutoff=$(( $(date +%s) - keep_days * 86400 ))
awk -F'\t' -v OFS='\t' -v reg="$registry" -v n="$keep_newest" -v cutoff="$cutoff" \
	-v inuse="$work/in-use" -v refd="$work/referenced" '
	BEGIN {
		while ((getline l < inuse) > 0) used[l] = 1
		while ((getline l < refd) > 0) code[l] = 1
		print "VERDICT", "REASON", "REPO", "TAG", "PUSHED"
	}
	{
		repo = $1; tag = $2; rank[repo]++
		ref = reg ":5000/" repo
		if (used[ref ":" tag] || used[ref "@" $4]) v = "keep\tin-use"
		else if (code[tag]) v = "keep\treferenced-in-code"
		else if (rank[repo] <= n) v = "keep\tnewest"
		else if ($3 >= cutoff) v = "keep\trecent"
		else v = "DELETE\told"
		print v, repo, tag, strftime("%F", $3)
	}' "$work/tags" > "$work/plan"

if [ "$apply" = no ]; then
	cat "$work/plan"
	awk -F'\t' 'NR > 1 { c[$1]++ } END { for (v in c) printf "%s: %d tags\n", v, c[v] }' "$work/plan" >&2
	exit 0
fi

# A push racing garbage-collect can lose freshly uploaded layers.
# Bracketed patterns keep pgrep from matching this script's own command line.
pgrep -f '[t]ilt (up|ci)|[d]ocker (build|push)|[b]uildx build' >/dev/null \
	&& die "a Tilt run, image build, or push is active; rerun when idle"

before=$(docker exec "$registry" du -sh /var/lib/registry | cut -f1)
awk -F'\t' '$1 == "DELETE" { print $3 " " $4 }' "$work/plan" \
	| docker exec -i "$registry" sh -c "cd $root && while read r t; do rm -rf \"\$r/_manifests/tags/\$t\"; done"
docker exec "$registry" registry garbage-collect --delete-untagged /etc/docker/registry/config.yml >/dev/null
# The blob descriptor cache is in memory; restart so deleted blobs are not served.
docker restart "$registry" >/dev/null
echo "deleted $(grep -c '^DELETE' "$work/plan") tags; registry $before -> $(docker exec "$registry" du -sh /var/lib/registry | cut -f1)"
