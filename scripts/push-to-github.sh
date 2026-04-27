#!/usr/bin/env bash
# Optional helper: set origin and push main.
# Usage: ./scripts/push-to-github.sh YOUR_GITHUB_USERNAME REPO_NAME

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [[ -z "${1:-}" ]] || [[ -z "${2:-}" ]]; then
  echo "Usage: $0 YOUR_GITHUB_USERNAME REPO_NAME"
  echo "Example: $0 directormihail anita"
  exit 1
fi

GITHUB_USER="$1"
REPO_NAME="$2"

if git remote get-url origin &>/dev/null; then
  echo "Removing existing origin..."
  git remote remove origin
fi

git remote add origin "https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
git branch -M main
git push -u origin main

echo "Done: https://github.com/${GITHUB_USER}/${REPO_NAME}"
