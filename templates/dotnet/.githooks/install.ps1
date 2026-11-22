# Turns on the repo's git hooks in this clone (once per clone), from PowerShell on Windows, macOS or Linux.
# The same as install.sh. See .githooks/README.md.
$ErrorActionPreference = 'Stop'
Set-Location (git rev-parse --show-toplevel)
git config core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'Git hooks on: every commit is checked for secrets with gitleaks.'
if (-not (Get-Command gitleaks -ErrorAction SilentlyContinue)) {
    if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') { $how = 'winget install Gitleaks.Gitleaks' }
    elseif ($IsMacOS) { $how = 'brew install gitleaks' }
    else { $how = 'see .githooks/README.md' }
    Write-Host "Tip: install gitleaks ($how). It is faster than the Docker fallback."
}
