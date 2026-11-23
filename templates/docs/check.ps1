# What CI runs before a pull request, on this machine: the build, the tests, the guard's tests and gitleaks over the
# whole history. Exit 1 if any of them fails. The same file in every Melderskin repo (from the templates in
# Melderskin/.github; the hub's sync-templates keeps it in step), so change it there. PowerShell 7, every OS.
#   pwsh ./check.ps1    or    bash check.sh
$ErrorActionPreference = 'Continue'
Set-Location $PSScriptRoot
$failed = [System.Collections.Generic.List[string]]::new()
function Step([string]$name, [scriptblock]$run) {
  Write-Host ''; Write-Host "=== check: $name ==="
  $global:LASTEXITCODE = 0
  try { & $run | Out-Host } catch { Write-Host $_ -ForegroundColor Red; $global:LASTEXITCODE = 1 }
  if ($LASTEXITCODE -ne 0) { $failed.Add($name) }
}

Step 'build' { pwsh -NoProfile -File ./build.ps1 }
Step 'test' { pwsh -NoProfile -File ./test.ps1 }
if (Test-Path .claude/hooks/guard.tests.ps1) { Step 'guard' { pwsh -NoProfile -File .claude/hooks/guard.tests.ps1 } }

# .NET repos: no package with a known vulnerability, as in the shared dotnet-ci.yml workflow.
if (Get-ChildItem -File -Filter *.sln* | Where-Object Extension -in '.sln', '.slnx') {
  Step 'packages' {
    $out = dotnet list package --vulnerable --include-transitive 2>&1
    $out | Out-Host
    if ($LASTEXITCODE -eq 0 -and ($out -match 'has the following vulnerable packages')) { $global:LASTEXITCODE = 1 }
  }
}

# The same scan as the shared secrets.yml workflow: gitleaks over every commit, with the same image (pinned by digest).
$image = 'ghcr.io/gitleaks/gitleaks:v8.28.0@sha256:cdbb7c955abce02001a9f6c9f602fb195b7fadc1e812065883f695d1eeaba854'
# Like secrets.yml, it fails unless gitleaks really read the history: an error line or 0 commits scanned fail it,
# since gitleaks can log a git error and still say "no leaks found".
Step 'secrets' {
  $inWorktree = (git rev-parse --git-dir) -ne (git rev-parse --git-common-dir)
  if (Get-Command gitleaks -ErrorAction SilentlyContinue) { $out = gitleaks git --redact --no-banner . 2>&1 }
  elseif ($inWorktree) {
    Write-Host 'This is a git worktree: gitleaks in Docker cannot read its history. Install gitleaks, or run check in the main clone.' -ForegroundColor Red
    $global:LASTEXITCODE = 1; return
  }
  elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    $repo = (Get-Location).Path.Replace([char]92, [char]47)  # E:\path -> E:/path for Docker on Windows
    $out = docker run --rm -v "${repo}:/repo" $image git /repo --redact --no-banner 2>&1
  } else {
    Write-Host 'gitleaks is needed to check for secrets: install it, or Docker (.githooks/README.md).' -ForegroundColor Red
    $global:LASTEXITCODE = 1; return
  }
  $code = $LASTEXITCODE
  $out | ForEach-Object { "$_" } | Out-Host
  $text = ($out | Out-String) -replace '\x1b\[[0-9;]*m', ''
  if ($code -eq 0 -and ($text -match '\bERR\b' -or $text -notmatch '([1-9]\d*) commits scanned')) {
    Write-Host 'gitleaks did not read the history (an error, or 0 commits scanned), so this is not a pass.' -ForegroundColor Red
    $code = 1
  }
  $global:LASTEXITCODE = $code
}

Write-Host ''
if ($failed.Count) { Write-Host "check failed: $($failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host 'check passed.' -ForegroundColor Green
