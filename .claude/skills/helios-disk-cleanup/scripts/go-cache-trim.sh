#!/usr/bin/env bash
# Clear the Go build cache once it exceeds a size cap. Go only trims entries
# unused for 5 days, and each worktree path gets its own cache entries, so
# parallel worktrees can add 100G+ in a day.
#
# Usage: go-cache-trim.sh [cap-in-GB]   (default 60)
# Runs from a systemd timer where `go` is not on PATH (it comes from the Helios
# nix shell), so it deletes the cache's hash dirs directly. Go treats missing
# entries as cache misses and recreates the dirs.
set -euo pipefail

cap_gb="${1:-60}"
cache="${GOCACHE:-$HOME/.cache/go-build}"
[ -d "$cache" ] || { echo "no Go cache at $cache"; exit 0; }

size_gb=$(( $(du -s --block-size=1G "$cache" | cut -f1) ))
if [ "$size_gb" -lt "$cap_gb" ]; then
	echo "Go cache ${size_gb}G is under the ${cap_gb}G cap; nothing to do"
	exit 0
fi

# Deleting entries mid-build can fail that build; skip and retry next run.
if pgrep -x compile >/dev/null || pgrep -x link >/dev/null; then
	echo "Go cache ${size_gb}G is over the cap, but a Go build is running; skipping"
	exit 0
fi

find "$cache" -mindepth 1 -maxdepth 1 -type d -name '[0-9a-f][0-9a-f]' -exec rm -rf {} +
echo "cleared Go cache: ${size_gb}G -> $(du -sh "$cache" | cut -f1)"
