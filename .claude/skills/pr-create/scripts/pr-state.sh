#!/bin/bash
# Gather all PR-relevant git state in one call

set -e

echo "=== Branch Info ==="
BRANCH=$(git branch --show-current)
echo "Current branch: $BRANCH"

# Check if branch has upstream
if git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
    UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u})
    echo "Upstream: $UPSTREAM"
    BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
    AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    echo "Ahead: $AHEAD, Behind: $BEHIND"
else
    echo "Upstream: (not set - will need to push with -u)"
fi

echo ""
echo "=== Uncommitted Changes ==="
if git diff --quiet && git diff --cached --quiet; then
    echo "None"
else
    git status --short
fi

echo ""
echo "=== Commits on this branch (vs main) ==="
# Try main first, then master
BASE_BRANCH="main"
if ! git rev-parse --verify main &>/dev/null; then
    BASE_BRANCH="master"
fi
echo "(comparing to $BASE_BRANCH)"
echo ""
git log --oneline "$BASE_BRANCH"..HEAD 2>/dev/null || echo "(no commits ahead of $BASE_BRANCH)"

echo ""
echo "=== Full commit messages ==="
git log --format="--- %h ---%n%B" "$BASE_BRANCH"..HEAD 2>/dev/null || true
