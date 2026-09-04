#!/usr/bin/env bash
# Push new course material.
#
#   ./update.sh                       render, commit, push
#   ./update.sh "Add week 8 slides"   the same, with your own commit message
#   ./update.sh -n "Fix a typo"       skip the render (text-only changes)
#
# The render matters: lecture decks are served from the committed _freeze/
# cache, so a deck you edited must be re-rendered here or the site build will
# fail in CI, where the decks' R packages are not installed.
set -euo pipefail
cd "$(dirname "$0")"

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "No 'origin' remote yet — run ./start.sh first." >&2
  exit 1
fi

render=yes
if [ "${1:-}" = "-n" ] || [ "${1:-}" = "--no-render" ]; then
  render=no
  shift
fi

message="${1:-Update course material}"

if [ "$render" = yes ]; then
  # Quarto ships inside RStudio and is often not on PATH.
  quarto=$(command -v quarto || true)
  if [ -z "$quarto" ]; then
    quarto=/usr/lib/rstudio/resources/app/bin/quarto/bin/quarto
  fi
  if [ ! -x "$quarto" ]; then
    echo "Could not find quarto. Install it, or run with -n to skip the render." >&2
    exit 1
  fi
  echo "==> Rendering the site"
  "$quarto" render
fi

if [ -z "$(git status --porcelain)" ]; then
  echo "==> Nothing has changed."
  exit 0
fi

echo "==> Committing"
git add -A
git status --short
git commit -m "$message"

echo "==> Pushing"
git push -u origin "$(git branch --show-current)"
echo
echo "Pushed. The site rebuilds automatically; watch it with:  gh run watch"
