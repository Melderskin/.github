# Claude Code Stop hook for .NET repos: the build and the tests must pass before an agent says it is done.
# Runs only when src/ or tests/ changed. Exit 2 sends Claude back to work with the failures. Skips (with a
# note) when OYONIX_TEST_DB is not set, so a session never loops. PowerShell 7, every OS. Source: Melderskin/.github.
$ErrorActionPreference = 'Continue'
try { $hook = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { $hook = $null }
if ($hook -and $hook.stop_hook_active) { exit 0 }

$root = git rev-parse --show-toplevel 2>$null
if (-not $root) { exit 0 }
Set-Location $root
if (-not (git status --porcelain -- src tests)) { exit 0 }

if (-not $env:OYONIX_TEST_DB) {
  [Console]::Error.WriteLine('Stop hook: OYONIX_TEST_DB is not set, so the tests did not run. Set it (README, "Tests") and run them before calling the work done.')
  exit 0
}

$build = dotnet build --nologo -v q 2>&1
if ($LASTEXITCODE -ne 0) {
  [Console]::Error.WriteLine("The build fails. Fix it before you finish:`n" + (($build | Select-Object -Last 30) -join "`n"))
  exit 2
}
$test = dotnet test --nologo --no-build --logger 'console;verbosity=minimal' 2>&1
if ($LASTEXITCODE -ne 0) {
  [Console]::Error.WriteLine("Tests fail. Fix them before you finish:`n" + (($test | Select-Object -Last 40) -join "`n"))
  exit 2
}
exit 0
