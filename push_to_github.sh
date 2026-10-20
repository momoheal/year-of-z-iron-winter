#!/usr/bin/env bash
set -e
REPO_NAME="${1:-year-of-z-iron-winter}"

echo "=== Pushing Year of Z: Iron Winter (v4.0) to GitHub ==="
if command -v gh >/dev/null 2>&1; then
  echo "Detected GitHub CLI (gh). Creating public repository '$REPO_NAME' and pushing..."
  gh repo create "$REPO_NAME" --public --source=. --remote=origin --push
  echo "✅ Successfully pushed to GitHub!"
else
  echo "GitHub CLI (gh) not found. Please enter your GitHub username:"
  read -r GH_USER
  git remote remove origin 2>/dev/null || true
  git remote add origin "https://github.com/${GH_USER}/${REPO_NAME}.git"
  git branch -M main
  git push -u origin main
fi
