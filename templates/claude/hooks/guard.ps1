# Claude Code PreToolUse guard: blocks what permission patterns can miss. One file for every Melderskin repo
# (source: templates/claude/ in Melderskin/.github; copy it, don't fork it). Exit 2 blocks the tool call and
# tells Claude why; printing a JSON "ask" decision makes Claude Code ask the person. PowerShell 7, every OS.
# Tests: templates/claude/hooks/guard.tests.ps1.
$ErrorActionPreference = 'Stop'

# --- Per repo: folders where the person is asked before an agent reads or writes (the hub: private, archive).
$AskFolders = @()  # hub: @('private', 'archive')

try { $hook = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { exit 0 }
$tool = $hook.tool_name
$ti = $hook.tool_input
$paths = (@($ti.file_path, $ti.path, $ti.pattern, $ti.notebook_path) | Where-Object { $_ }) -join "`n"
$cmd = if ($tool -in 'Bash', 'PowerShell') { [string]$ti.command } else { '' }
$all = (($paths, $cmd) -join "`n") -replace '\\', '/'

function Block([string]$why) { [Console]::Error.WriteLine("Blocked by .claude/hooks/guard.ps1: $why."); exit 2 }
function Ask([string]$why) {
  @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'ask'; permissionDecisionReason = $why } } |
    ConvertTo-Json -Compress -Depth 4
  exit 0
}

# 1. Secret files, by path or inside a command (cat .env, Get-Content secrets.json, ...)
if ($all -match '(^|[/\s"''=])\.env(\.[\w-]+)?($|[\s"''/;|&])' -or
    $all -match '(?i)secrets\.json|usersecrets|\.pfx\b|\.p12\b|\.pem\b|\bid_rsa\b|\bid_ed25519\b|settings\.local\.json') {
  Block 'secret files are off limits for agents'
}

if ($cmd) {
  # 2. Printing secrets from the environment. Checked on the raw command, quotes included.
  if ($cmd -match '(?i)(\$env:|\$\{?|%)\w*(TOKEN|SECRET|PASSWORD|PASSWD|APIKEY|API_KEY|CONNECTION|CONNSTR|_DB)\w*') {
    Block 'reading secret environment variables can leak them'
  }

  # Quoted text (commit messages, PR bodies, heredoc lines in quotes) can't run anything: drop it, then look at
  # each command in a chain on its own, so `git push x && gh pr create --base main` is two commands, not one.
  $bare = $cmd -replace '"(?:[^"\\]|\\.)*"', '""' -replace "'[^']*'", "''"
  $segments = $bare -split '&&|\|\||;|\||\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

  foreach ($s in $segments) {
    if ($s -match '^(printenv|env|set)$' -or $s -match '(?i)^(Get-ChildItem|gci|dir|ls)\s+env:') {
      Block 'printing the environment can leak connection strings and tokens'
    }
    if ($s -match '^git(\s+-C\s+\S+)?\s+(?<rest>.*)$') {
      $rest = $Matches.rest
      if ($rest -match '^push\b') {
        if ($rest -match '(\s)(--force|--force-with-lease|-f)(\s|=|$)|\s\+\S') { Block 'force push' }
        if ($rest -match '(\s|:)(main|master)(\s|$)') { Block 'pushing to main: open a pull request instead' }
      }
      if ($rest -match '(^|\s)--no-verify(\s|$)') { Block '--no-verify would skip the gitleaks hook' }
      if ($rest -match '^reset\b.*\s--hard\b') { Block 'git reset --hard throws work away' }
    }
    if ($s -match '^gh\s+(secret\b|repo\s+delete\b|api\b.*(-X|--method)\s*(DELETE|PUT|PATCH|POST)\b)') {
      Block 'GitHub secrets, repo deletion and settings changes are for Kenneth'
    }
    if ($s -match '^gh\s+pr\s+merge\b') { Ask "Merging is Kenneth's decision" }
  }
}

# 3. Folders the person guards (set per repo above)
foreach ($f in $AskFolders) {
  if ($all -match "(^|/)$([regex]::Escape($f))(/|$)") { Ask "$f/ is a private folder: the person decides" }
}

# 4. Existing database migrations are never edited (add a new one instead)
if ($tool -in 'Edit', 'Write', 'MultiEdit' -and $ti.file_path) {
  $p = $ti.file_path -replace '\\', '/'
  if ($p -match '/Migrations/' -and (Test-Path -LiteralPath $ti.file_path)) { Block 'existing migrations are never edited; add a new migration' }
}

exit 0
