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
  & $run | Out-Host
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
Step 'secrets' {
  if (Get-Command gitleaks -ErrorAction SilentlyContinue) { gitleaks git --redact --no-banner . }
  elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    $repo = (Get-Location).Path -replace '\', '/'
    docker run --rm -v "${repo}:/repo" $image git /repo --redact --no-banner
  } else {
    Write-Host 'gitleaks is needed to check for secrets: install it, or Docker (.githooks/README.md).' -ForegroundColor Red
    $global:LASTEXITCODE = 1
  }
}

Write-Host ''
if ($failed.Count) { Write-Host "check failed: $($failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host 'check passed.' -ForegroundColor Green
