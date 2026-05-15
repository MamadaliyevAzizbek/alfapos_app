#!/usr/bin/env bash
# Alfapos — GitHub'ga yuklash va Windows build ishga tushirish
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GH="${GH:-/opt/homebrew/bin/gh}"
REPO_NAME="${REPO_NAME:-alfapos_app}"
GITHUB_USER="${GITHUB_USER:-MamadaliyevAzizbek}"

if ! "$GH" auth status &>/dev/null; then
  echo "GitHub'ga kirmagansiz. Quyidagi buyruqni ishga tushiring:"
  echo "  $GH auth login -h github.com -p https -w"
  exit 1
fi

echo ">> Repo yaratilmoqda (agar yo'q bo'lsa)..."
if ! "$GH" repo view "$GITHUB_USER/$REPO_NAME" &>/dev/null; then
  "$GH" repo create "$REPO_NAME" --public --source=. --remote=origin --push
else
  git remote remove origin 2>/dev/null || true
  git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
  git push -u origin main
fi

echo ">> Windows build ishga tushirilmoqda..."
"$GH" workflow run build-windows.yml

echo ""
echo "Tayyor! Build holatini ko'ring:"
echo "  https://github.com/$GITHUB_USER/$REPO_NAME/actions"
echo ""
echo "Build tugagach Artifacts dan alfapos-windows-release.zip ni yuklab oling."
