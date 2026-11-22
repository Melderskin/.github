#!/bin/sh
# Turns on the repo's git hooks in this clone (once per clone), on macOS and Linux (or Git Bash on Windows).
# From PowerShell, use install.ps1. See .githooks/README.md.
set -e
cd "$(git rev-parse --show-toplevel)"
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
echo "Git hooks on: every commit is checked for secrets with gitleaks."
if ! command -v gitleaks >/dev/null 2>&1; then
  case "$(uname -s)" in
    Darwin) how="brew install gitleaks" ;;
    MINGW*|MSYS*|CYGWIN*) how="winget install Gitleaks.Gitleaks" ;;
    *) how="see .githooks/README.md" ;;
  esac
  echo "Tip: install gitleaks ($how). It is faster than the Docker fallback."
fi
