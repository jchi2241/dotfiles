#!/usr/bin/env bash
# Read-only worktree audit. Classifies every non-main worktree of a repo and
# suggests a bucket. Never deletes; removal is the agent's gated step.
#
# Usage: worktree-audit.sh [repo-path]   (defaults to ~/projects/helios)
# Output: TSV sorted by size. TICKET is a Jira key parsed from the branch;
# the script cannot see Jira, so the agent resolves `check-ticket` rows.
set -u

repo="${1:-$HOME/projects/helios}"
cd "$repo" || exit 1
main_wt=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
now=$(date +%s)

git fetch origin master --quiet 2>/dev/null || echo "warn: fetch failed; MERGED may be stale" >&2

# Process cwds, read once. A shell, tilt, or agent sitting in a worktree means in use.
cwds=$(for p in /proc/[0-9]*; do readlink "$p/cwd" 2>/dev/null; done | sort -u)

# Claude and Cursor transcripts touched in the last 4 days, read once.
recent_transcripts=$(find "$HOME/.claude/projects" "$HOME/.cursor/projects" \
	-name '*.jsonl' -mtime -4 2>/dev/null)

printf "SIZE\tAGE\tMERGED\tDIRTY\tPR\tTICKET\tLAST_CHAT\tIN_USE\tBUCKET\tWORKTREE\n"

git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r wt; do
	[ "$wt" = "$main_wt" ] && continue
	if [ ! -d "$wt" ]; then
		printf -- "-\t-\t-\t-\t-\t-\t-\t-\tmissing-dir\t%s\n" "$wt"
		continue
	fi

	size=$(du -sh "$wt" 2>/dev/null | cut -f1)
	head=$(git -C "$wt" rev-parse HEAD)
	age="$(( (now - $(git -C "$wt" log -1 --format=%ct)) / 86400 ))d"
	branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD || true)

	# Squash merges are not ancestors of master; PR state is the main merge signal.
	git merge-base --is-ancestor "$head" origin/master && merged=YES || merged=no

	porcelain=$(git -C "$wt" status --porcelain)
	if [ -z "$porcelain" ]; then dirty=clean
	elif grep -qv '^??' <<<"$porcelain"; then dirty="wip:$(grep -cv '^??' <<<"$porcelain")"
	else dirty="scratch:$(grep -c '^??' <<<"$porcelain")"; fi

	# Removing a worktree keeps its branch ref, so only commits on no branch are at risk.
	orphan=no
	[ "$merged" = no ] && [ -z "$(git branch -a --contains "$head" 2>/dev/null)" ] && orphan=yes

	pr="-"
	[ -n "$branch" ] && pr=$(gh pr list --head "$branch" --state all --limit 1 \
		--json number,state -q '.[] | "#\(.number)/\(.state)"' 2>/dev/null)
	[ -z "$pr" ] && pr="-"

	ticket=$(grep -oE '[A-Z][A-Z0-9]+-[0-9]+' <<<"$branch" | head -1)
	[ -z "$ticket" ] && ticket="-"

	# Match the path followed by / or a quote so foo does not match foo-2.
	last="-"; recent=no
	f=$(grep -lF -e "$wt/" -e "$wt\"" $recent_transcripts 2>/dev/null \
		| xargs -r stat -c '%Y' | sort -rn | head -1)
	[ -n "$f" ] && { last=$(date -d "@$f" +%F); recent=yes; }

	in_use=no
	grep -qE "^$wt(/|$)" <<<"$cwds" && in_use=yes

	if [ "$in_use" = yes ]; then bucket=hold-in-use
	elif [[ $dirty == wip:* ]]; then bucket=hold-wip
	elif [ "$orphan" = yes ]; then bucket=hold-orphan-commits
	elif [[ $pr == */OPEN ]]; then bucket=hold-open-pr
	elif [ "$recent" = yes ]; then bucket=verify-recent-chat
	elif [ "$merged" = YES ] || [[ $pr == */MERGED || $pr == */CLOSED ]]; then bucket=safe
	elif [ "$ticket" != "-" ]; then bucket=check-ticket
	else bucket=review; fi

	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
		"$size" "$age" "$merged" "$dirty" "$pr" "$ticket" "$last" "$in_use" "$bucket" "$wt"
done | sort -t$'\t' -k1,1 -rh
