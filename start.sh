#!/usr/bin/env bash
# One-time bootstrap: make the first commit and create the private GitHub
# repository. After this, use ./update.sh for everything.
set -euo pipefail
cd "$(dirname "$0")"

if git remote get-url origin >/dev/null 2>&1; then
  echo "origin already exists: $(git remote get-url origin)"
  echo "Nothing to bootstrap — use ./update.sh to push changes."
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "The GitHub CLI (gh) is not installed: https://cli.github.com" >&2
  exit 1
fi
# `gh auth status` exits 0 even when the stored token has expired, so make a
# real API call instead.
if ! gh api user >/dev/null 2>&1; then
  echo "GitHub token is missing or expired. Run:  gh auth login -h github.com" >&2
  exit 1
fi

# GitHub and the workflows expect the branch to be called main.
[ "$(git branch --show-current)" = "master" ] && git branch -m master main

git add -A
if [ -n "$(git status --porcelain)" ]; then
  git commit -m "Reorganise as a course website"
else
  echo "Already committed — creating the repository from what is here."
fi

gh repo create MolEcoMeth --private --source=. --remote=origin --push

echo
echo "Done. Next, in the repository settings:"
echo "  1. Pages   -> Source: GitHub Actions"
echo "  2. Collaborators -> add the students with Write"
echo "  3. Secrets and variables -> Actions -> new secret SESSION_PEPPER"
echo "  4. Rules   -> require the 'Seminar guard / guard' check on main"
echo "See MAINTAINING.md for the details."
