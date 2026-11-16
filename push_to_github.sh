#!/usr/bin/env bash
# Safe push helper — Year of Z: Iron Winter (build 4.0.0)
#
# ONLY pushes the CURRENT BRANCH to the ALREADY-CONFIGURED origin.
# It does NOT create a remote repository, overwrite origin, or rename the branch.
# (Earlier versions created a remote repo and renamed the branch; both
#  behaviours were unsafe for this repo and have been removed.)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

echo "=== Year of Z: Iron Winter — push current branch only (build 4.0.0) ==="

ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
CURRENT_BRANCH="$(git branch --show-current)"

if [ -z "$ORIGIN_URL" ]; then
  echo "ERROR: no 'origin' remote is configured. Ask the repo owner to configure it, then re-run." >&2
  echo "       This script intentionally never creates or overwrites a remote." >&2
  exit 1
fi
if [ -z "$CURRENT_BRANCH" ]; then
  echo "ERROR: detached HEAD — check out a branch before pushing." >&2
  exit 1
fi

echo "origin : $ORIGIN_URL"
echo "branch : $CURRENT_BRANCH"
echo "NOTE  : this script will NOT create a repo, overwrite origin, or rename the branch."
echo "NOTE  : pushing is a high-impact action — confirm the two lines above before proceeding."
echo "NOTE  : to see what would be pushed without sending it, run: git log --oneline origin/$CURRENT_BRANCH..HEAD"

# Push the current branch only. HEAD resolves to the current branch; no -M rename, no origin rewrite.
git push -u origin HEAD

echo "Pushed '$CURRENT_BRANCH' to origin."
echo "To merge into main, open a Pull Request (do NOT rename the branch):"
echo "  gh pr create --base main --head HEAD --fill"
