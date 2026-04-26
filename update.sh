#!/usr/bin/env bash
#
# update.sh — regenerate the repo's Brewfile from the currently
# installed brew formulae and casks. Intended for personal sync;
# review `git diff Brewfile` before committing.
#
# Not to be confused with `bin/update`, which is the multi-package-
# manager updater that the shell `update` alias calls.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

cd "$DOTFILES_DIR"

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: brew not on PATH; cannot regenerate Brewfile." >&2
  exit 1
fi

echo "==> Regenerating Brewfile from current system"
rm -f Brewfile
brew bundle dump --file=Brewfile

echo
echo "==> git diff --stat Brewfile"
git -C "$DOTFILES_DIR" diff --stat Brewfile || true
