# Tests for guard.ps1: pwsh -NoProfile -File templates/claude/hooks/guard.tests.ps1 [path-to-guard.ps1]
# Every rule has a case that must be blocked and a look-alike that must pass. Exit 1 if any case fails.
param([string]$Guard = (Join-Path $PSScriptRoot 'guard.ps1'))

function Run($tool, $toolInput) {
  $json = @{ tool_name = $tool; tool_input = $toolInput } | ConvertTo-Json -Compress -Depth 4
  $out = $json | pwsh -NoProfile -File $Guard 2>&1
  if ($LASTEXITCODE -eq 2) { 'block' } elseif ("$out" -match '"permissionDecision":"ask"') { 'ask' } else { 'pass' }
}

$cases = @(
  # tool, input, expected
  @('Read', @{ file_path = 'E:/repo/.env' }, 'block'),
  @('Read', @{ file_path = 'E:/repo/src/environment.cs' }, 'pass'),
  @('Bash', @{ command = 'cat secrets.json' }, 'block'),
  @('Bash', @{ command = 'echo $OYONIX_TEST_DB' }, 'block'),
  @('PowerShell', @{ command = 'Write-Output $env:GITHUB_TOKEN' }, 'block'),
  @('Bash', @{ command = 'dotnet test --nologo' }, 'pass'),
  @('Bash', @{ command = 'printenv' }, 'block'),
  @('PowerShell', @{ command = 'Get-ChildItem env:' }, 'block'),
  @('Bash', @{ command = 'git push --force origin claude/x' }, 'block'),
  @('Bash', @{ command = 'git push origin +claude/x' }, 'block'),
  @('Bash', @{ command = 'git push origin main' }, 'block'),
  @('Bash', @{ command = 'git push origin HEAD:main' }, 'block'),
  @('Bash', @{ command = 'git -C repo push origin main' }, 'block'),
  @('Bash', @{ command = 'git push -u origin claude/x && gh pr create --base main --title "x"' }, 'pass'),
  @('Bash', @{ command = 'git push -u origin claude/main-fix' }, 'pass'),
  @('Bash', @{ command = 'git commit --no-verify -m "x"' }, 'block'),
  @('Bash', @{ command = 'git commit -m "Never use --no-verify here"' }, 'pass'),
  @('Bash', @{ command = "git commit -F - <<'EOF'`nskips the hook (--no-verify) never`nEOF" }, 'pass'),
  @('Bash', @{ command = 'git reset --hard HEAD~1' }, 'block'),
  @('Bash', @{ command = 'git reset --soft HEAD~1' }, 'pass'),
  @('Bash', @{ command = 'gh secret set X' }, 'block'),
  @('Bash', @{ command = 'gh api -X DELETE repos/a/b' }, 'block'),
  @('Bash', @{ command = 'gh api repos/a/b/pulls' }, 'pass'),
  @('Bash', @{ command = 'gh pr merge 5 --merge' }, 'ask'),
  @('Bash', @{ command = 'gh pr view 5' }, 'pass'),
  @('Bash', @{ command = 'echo "use gh pr merge later"' }, 'pass'),
  @('Edit', @{ file_path = 'E:/repo/docs/readme.md' }, 'pass')
)

$failed = 0
foreach ($c in $cases) {
  $got = Run $c[0] $c[1]
  if ($got -ne $c[2]) { $failed++; Write-Host "FAIL  $($c[0]) $($c[1] | ConvertTo-Json -Compress): expected $($c[2]), got $got" }
}
Write-Host "$($cases.Count - $failed) of $($cases.Count) cases pass"
exit [int]($failed -gt 0)
