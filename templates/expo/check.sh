#!/usr/bin/env bash
# Runs the PowerShell script of the same name (build.sh runs build.ps1, and so on), so every command works from bash
# and from PowerShell on Windows, macOS and Linux. Needs PowerShell 7 (pwsh):  macOS: brew install --cask powershell
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v pwsh >/dev/null 2>&1; then
  echo "PowerShell 7 (pwsh) is required. On macOS: brew install --cask powershell" >&2
  exit 1
fi
pwsh -NoProfile -File "./$(basename "$0" .sh).ps1" "$@"
