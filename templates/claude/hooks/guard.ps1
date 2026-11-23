# Claude Code PreToolUse guard: blocks what permission patterns can miss. One file for every Melderskin repo
# (source: templates/claude/ in Melderskin/.github; copy it, don't fork it). Exit 2 blocks the tool call and
# tells Claude why; printing a JSON "ask" decision makes Claude Code ask the person. PowerShell 7, every OS.
# Tests: pwsh -NoProfile -File .claude/hooks/guard.tests.ps1
#
# Commands are split into tokens and segments the way the shell would (bash or PowerShell quoting, comments,
# heredocs, here-strings, &&, ||, ;, |, &, parentheses and braces), and each rule looks only at its own command:
# `gh pr create --base main` is not a push, and a commit message is not a file read. Fail closed: if the parser
# throws or a quote, heredoc or here-string is left open, the old whole-string rules run as well.
$ErrorActionPreference = 'Stop'

# --- Per repo: folders where the person is asked before an agent reads or writes (the hub: private, archive).
$AskFolders = @('private', 'archive')

try { $hook = [Console]::In.ReadToEnd() | ConvertFrom-Json } catch { exit 0 }
$tool = $hook.tool_name
$ti = $hook.tool_input
$paths = (@($ti.file_path, $ti.path, $ti.pattern, $ti.notebook_path) | Where-Object { $_ }) -join "`n"
$cmd = if ($tool -in 'Bash', 'PowerShell') { [string]$ti.command } else { '' }
$all = (($paths, $cmd) -join "`n") -replace '\\', '/'
$script:askWhy = $null
$script:scan = [System.Text.StringBuilder]::new()  # command text the secret-file rule looks at
$script:switchedTo = $null                           # branch a `git checkout/switch` earlier in the command moves to
$Shells = 'bash', 'sh', 'zsh', 'dash', 'ksh', 'fish', 'pwsh', 'powershell', 'cmd', 'wsl', 'eval', 'invoke-expression', 'iex'
$PsShells = 'pwsh', 'powershell', 'invoke-expression', 'iex'
$Interpreters = 'python', 'python2', 'python3', 'py', 'node', 'nodejs', 'deno', 'bun', 'perl', 'ruby', 'php', 'lua', 'osascript'
$SecretVar = '(?i)(TOKEN|SECRET|PASSWORD|PASSWD|APIKEY|API_KEY|CONNECTION|CONNSTR|_DB)'
$Writers = 'sed', 'perl', 'tee', 'truncate', 'dd', 'mv', 'cp', 'rm', 'del', 'erase', 'move', 'copy', 'ren', 'rename',
  'set-content', 'sc', 'add-content', 'ac', 'out-file', 'clear-content', 'clc', 'remove-item', 'ri', 'move-item', 'mi',
  'copy-item', 'cpi', 'rename-item', 'rni', 'new-item', 'ni'
# Git's own commands: an alias can't replace them, so only other words are looked up as aliases.
$GitBuiltins = 'add', 'am', 'apply', 'bisect', 'blame', 'branch', 'checkout', 'cherry-pick', 'clean', 'clone', 'commit', 'config',
  'describe', 'diff', 'fetch', 'grep', 'init', 'log', 'ls-files', 'ls-remote', 'merge', 'mv', 'notes', 'pull', 'push', 'rebase',
  'reflog', 'remote', 'reset', 'restore', 'rev-list', 'rev-parse', 'revert', 'rm', 'shortlog', 'show', 'stash', 'status',
  'switch', 'symbolic-ref', 'tag', 'worktree', 'cat-file', 'for-each-ref', 'merge-base', 'name-rev', 'range-diff', 'gc', 'help', 'version'

function Block([string]$why) { [Console]::Error.WriteLine("Blocked by .claude/hooks/guard.ps1: $why."); exit 2 }
function Ask([string]$why) {
  @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'ask'; permissionDecisionReason = $why } } |
    ConvertTo-Json -Compress -Depth 4
  exit 0
}

function Test-SecretFile([string]$s) {
  $s = $s -replace '\\', '/'
  ($s -match '(^|[/\s"''=<>(@:])\.env(\.[\w-]+)?($|[\s"''/;|&)`])') -or
  ($s -match '(?i)secrets\.json|usersecrets|\.pfx\b|\.p12\b|\.pem\b|\bid_rsa\b|\bid_ed25519\b|settings\.local\.json')
}

# --- Parsing -------------------------------------------------------------------------------------------------

function New-Segment {
  [pscustomobject]@{ Tokens = [System.Collections.Generic.List[string]]::new(); Bodies = [System.Collections.Generic.List[object]]::new(); HasPending = $false; PipesOut = $false }
}

# Splits a command line into segments (one command each). Heredoc bodies go to their segment's Bodies.
# $ps: PowerShell quoting (backtick escapes, '' and "" inside quotes, no \ escapes, no heredocs) instead of bash.
# Returns Segs, and Incomplete when a quote, comment, heredoc or here-string is left open.
function Split-Command([string]$text, [bool]$ps) {
  $segs = [System.Collections.Generic.List[object]]::new()
  $seg = New-Segment
  $tok = [System.Text.StringBuilder]::new()
  $inTok = $false
  $incomplete = $false
  $pending = [System.Collections.Generic.List[object]]::new()
  $n = $text.Length
  $i = 0
  $flush = { if ($inTok) { $seg.Tokens.Add($tok.ToString()); [void]$tok.Clear(); $inTok = $false } }
  $endSeg = { . $flush; if ($seg.Tokens.Count -or $seg.Bodies.Count -or $seg.HasPending) { $segs.Add($seg) }; $seg = New-Segment }

  while ($i -lt $n) {
    $c = $text[$i]

    # Comments: # at the start of a word (bash and PowerShell), <# ... #> (PowerShell).
    if (-not $inTok -and $c -eq '#') {
      $eol = $text.IndexOf("`n", $i); if ($eol -lt 0) { $eol = $n }
      $i = $eol
      continue
    }
    if ($ps -and -not $inTok -and $c -eq '<' -and $i + 1 -lt $n -and $text[$i + 1] -eq '#') {
      $j = $text.IndexOf('#>', $i + 2)
      if ($j -lt 0) { $incomplete = $true; $i = $n } else { $i = $j + 2 }
      continue
    }
    # PowerShell here-string: @' or @" at the end of a line, closed by '@ or "@ at the start of a line.
    if ($ps -and $c -eq '@' -and -not $inTok -and $i + 1 -lt $n -and ($text[$i + 1] -eq "'" -or $text[$i + 1] -eq '"')) {
      $eol = $text.IndexOf("`n", $i + 2)
      if ($eol -ge 0 -and $text.Substring($i + 2, $eol - $i - 2).Trim() -eq '') {
        $after = $text.Substring($eol + 1)
        $m = [regex]::Match($after, '(?m)^' + [regex]::Escape("$($text[$i + 1])@"))
        if (-not $m.Success) { $incomplete = $true; break }
        [void]$tok.Append(($after.Substring(0, $m.Index) -replace '\r?\n$', '')); $inTok = $true
        $i = $eol + 1 + $m.Index + 2
        continue
      }
    }
    if ($c -eq "'") {
      $i++
      while ($true) {
        $j = $text.IndexOf("'", $i)
        if ($j -lt 0) { [void]$tok.Append($text.Substring($i)); $i = $n; $incomplete = $true; break }
        [void]$tok.Append($text, $i, $j - $i)
        if ($ps -and $j + 1 -lt $n -and $text[$j + 1] -eq "'") { [void]$tok.Append("'"); $i = $j + 2; continue }
        $i = $j + 1
        break
      }
      $inTok = $true
      continue
    }
    if ($c -eq '"') {
      $i++
      $closed = $false
      while ($i -lt $n) {
        $d = $text[$i]
        if ($d -eq '"') {
          if ($ps -and $i + 1 -lt $n -and $text[$i + 1] -eq '"') { [void]$tok.Append('"'); $i += 2; continue }
          $closed = $true; break
        }
        if ($ps) {
          if ($d -eq '`' -and $i + 1 -lt $n) { [void]$tok.Append($text[$i + 1]); $i += 2; continue }
        }
        else {
          if ($d -eq '\' -and $i + 1 -lt $n -and $text[$i + 1] -eq '"') { [void]$tok.Append('"'); $i += 2; continue }
          if ($d -eq '\' -and $i + 1 -lt $n -and $text[$i + 1] -eq '\') { [void]$tok.Append('\\'); $i += 2; continue }
        }
        [void]$tok.Append($d); $i++
      }
      if (-not $closed) { $incomplete = $true }
      $inTok = $true; $i++
      continue
    }
    if ($c -eq ' ' -or $c -eq "`t" -or $c -eq "`r") { . $flush; $i++; continue }
    if ($c -eq "`n") {
      . $endSeg; $i++
      foreach ($h in $pending) {
        $body = [System.Text.StringBuilder]::new()
        $found = $false
        while ($i -lt $n) {
          $eol = $text.IndexOf("`n", $i); if ($eol -lt 0) { $eol = $n }
          $line = $text.Substring($i, $eol - $i).TrimEnd("`r")
          $i = [Math]::Min($eol + 1, $n)
          if ($(if ($h.Dash) { $line.TrimStart("`t") } else { $line }) -eq $h.Delim) { $found = $true; break }
          [void]$body.AppendLine($line)
        }
        if (-not $found) { $incomplete = $true }
        $h.Seg.Bodies.Add([pscustomobject]@{ Text = $body.ToString(); Expands = -not $h.Quoted })
      }
      $pending.Clear()
      continue
    }
    if ($ps) {
      # Backtick: line continuation or an escaped character. A backslash is just a character.
      if ($c -eq '`' -and $i + 1 -lt $n) {
        if ($text[$i + 1] -eq "`n") { $i += 2; continue }
        if ($text[$i + 1] -eq "`r" -and $i + 2 -lt $n -and $text[$i + 2] -eq "`n") { $i += 3; continue }
        [void]$tok.Append($text[$i + 1]); $inTok = $true; $i += 2
        continue
      }
    }
    elseif ($c -eq '\' -and $i + 1 -lt $n) {
      $d = $text[$i + 1]
      if ($d -eq "`n") { $i += 2; continue }
      if ($d -eq "`r" -and $i + 2 -lt $n -and $text[$i + 2] -eq "`n") { $i += 3; continue }
      if ([string]$d -in ' ', "`t", '"', "'", ';', '|', '&', '<', '>', '(', ')', '{', '}', '\', '#', '`') { [void]$tok.Append($d); $inTok = $true; $i += 2; continue }
      [void]$tok.Append($c); $inTok = $true; $i++
      continue
    }
    if ($c -eq ';' -or $c -eq '(' -or $c -eq ')' -or $c -eq '{' -or $c -eq '}') { . $endSeg; $i++; continue }
    if ($c -eq '|') {
      $double = $i + 1 -lt $n -and $text[$i + 1] -eq '|'
      if (-not $double) { $seg.PipesOut = $true }
      . $endSeg
      $i += $(if ($i + 1 -lt $n -and ($text[$i + 1] -eq '|' -or $text[$i + 1] -eq '&')) { 2 } else { 1 })
      continue
    }
    if ($c -eq '&') {
      if ($i + 1 -lt $n -and $text[$i + 1] -eq '&') { . $endSeg; $i += 2; continue }
      $prev = if ($tok.Length) { $tok[$tok.Length - 1] } else { [char]0 }
      if ($prev -eq '>' -or $prev -eq '<' -or ($i + 1 -lt $n -and $text[$i + 1] -eq '>')) { [void]$tok.Append($c); $inTok = $true; $i++; continue }
      . $endSeg; $i++
      continue
    }
    if (-not $ps -and $c -eq '<' -and $i + 1 -lt $n -and $text[$i + 1] -eq '<') {
      . $flush
      if ($i + 2 -lt $n -and $text[$i + 2] -eq '<') { $seg.Tokens.Add('<<<'); $i += 3; continue }
      $i += 2; $dash = $false
      if ($i -lt $n -and $text[$i] -eq '-') { $dash = $true; $i++ }
      while ($i -lt $n -and ($text[$i] -eq ' ' -or $text[$i] -eq "`t")) { $i++ }
      $delim = [System.Text.StringBuilder]::new(); $quoted = $false
      while ($i -lt $n -and [string]$text[$i] -notin ' ', "`t", "`r", "`n", ';', '|', '&', '<', '>', '(', ')') {
        if ([string]$text[$i] -in "'", '"', '\') { $quoted = $true } else { [void]$delim.Append($text[$i]) }
        $i++
      }
      if ($delim.Length) { $pending.Add([pscustomobject]@{ Seg = $seg; Delim = $delim.ToString(); Dash = $dash; Quoted = $quoted }); $seg.HasPending = $true }
      else { $incomplete = $true }
      continue
    }
    [void]$tok.Append($c); $inTok = $true; $i++
  }
  . $endSeg
  if ($pending.Count) { $incomplete = $true }
  [pscustomobject]@{ Segs = $segs; Incomplete = $incomplete }
}

function Get-Name([string]$t) { (($t -split '[/\\]')[-1]).ToLowerInvariant() -replace '\.exe$', '' }

# Text that can run something when the shell expands it.
function Test-Expands([string]$s) { $s.Contains('$(') -or $s.Contains('`') }

# A message value is data unless it runs something. "$(cat <<'EOF' ... EOF)" (the usual commit-message form) is data.
function Test-DataValue([string]$s) {
  if (-not (Test-Expands $s)) { return $true }
  $m = [regex]::Match($s, '^\s*\$\(\s*cat\s+<<-?\s*(?<q>[''"]?)(?<d>\w+)\k<q>[ \t]*\r?\n(?<b>.*?)\r?\n[ \t]*\k<d>[ \t]*(\r?\n)?\s*\)\s*$', 'Singleline')
  $m.Success -and ($m.Groups['q'].Value -or -not (Test-Expands $m.Groups['b'].Value))
}

# Git takes any unambiguous prefix of a long option (--no-verif, --forc, --al): treat one as the full option.
function Test-LongOption([string]$o, [string]$full) {
  $name = $o.Split('=')[0]
  $name.Length -ge 4 -and $full.StartsWith($name, [StringComparison]::OrdinalIgnoreCase)
}

function Resolve-Dir([string]$base, [string]$p) {
  if (-not $p) { return $base }
  if ($p -eq '~' -or $p.StartsWith('~/')) { $p = $HOME + $p.Substring(1) }
  if ($IsWindows -and $p -match '^/([a-zA-Z])(/|$)') { $p = "$($Matches[1]):/" + $p.Substring([Math]::Min(3, $p.Length)) }
  if (-not $base -or [System.IO.Path]::IsPathRooted($p)) { return $p }
  [System.IO.Path]::Combine($base, $p)
}

# Branches a bare `git push` would update: the current branch and its push target.
function Get-PushTargets([string]$dir) {
  if ($script:switchedTo) { return @($script:switchedTo) }
  $r = @()
  try {
    $b = & git -C $dir symbolic-ref --short -q HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $b) { $r += "$b" }
    $p = & git -C $dir rev-parse --abbrev-ref --symbolic-full-name '@{push}' 2>$null
    if ($LASTEXITCODE -eq 0 -and $p) { $r += ("$p" -replace '^[^/]+/', '') }
  } catch { }
  $r
}

function Test-MainRef([string]$ref) { ($ref -replace '^(refs/)?(heads/)?', '') -in 'main', 'master' }

function Test-GitConfigKey([string]$s) {
  $s = $s -replace '^--config-env=', ''
  if ($s -match '(?i)^core\.hookspath(=|$)') { Block 'changing core.hooksPath would skip the gitleaks hook' }
  if ($s -match '(?i)^alias\.') { Block 'git aliases set on the command line cannot be checked' }
}

# The rules from before the parser, on a whole string. For text the parser can't see into (interpreter code,
# broken quoting): they fail closed.
function Test-LegacyRules([string]$c) {
  if ($c -match '\bgit\b.*\bpush\b.*(\s--force\b|\s-f\b|--force-with-lease|\s\+[\w/])') { Block 'force push' }
  if ($c -match '\bgit\b.*\bpush\b.*(\s|:|/)(main|master)($|[\s''"`);&|])') { Block 'pushing to main: open a pull request instead' }
  if ($c -match '--no-verify') { Block '--no-verify would skip the gitleaks hook' }
  if ($c -match '\bgit\b.*\breset\s+--hard') { Block 'git reset --hard throws work away' }
  if ($c -match '\bgh\s+(secret|repo|api|variable|auth)\b') { Block 'GitHub secrets, repo deletion and settings changes are for a person, not an agent' }
  if ($c -match '(^|[;&|]\s*)(printenv|env|set)\s*($|[;&|])' -or $c -match '(?i)(Get-ChildItem|gci|dir|ls)\s+env:') { Block 'printing the environment can leak connection strings and tokens' }
  if ($c -match '\bgh\s+pr\s+merge\b') { $script:askWhy = "Merging is a person's decision" }
}

# --- Rules per command -----------------------------------------------------------------------------------------

function Test-Push([string[]]$a, [string]$dir) {
  $pos = [System.Collections.Generic.List[string]]::new()
  for ($j = 0; $j -lt $a.Count; $j++) {
    $o = $a[$j]
    if ($o -eq '--') { $pos.AddRange([string[]]@($a | Select-Object -Skip ($j + 1))); break }
    if ($o.StartsWith('--')) {
      if ($o -match '^--(force-with-lease|force-if-includes)' -or (Test-LongOption $o '--force')) { Block 'force push' }
      if ((Test-LongOption $o '--all') -or (Test-LongOption $o '--mirror') -or (Test-LongOption $o '--branches')) { Block 'git push --all/--mirror also pushes main: push one branch' }
      if ($o -in '--repo', '--push-option', '--receive-pack', '--exec') { $j++ }
      continue
    }
    if ($o -cmatch '^-[a-zA-Z]+$') {
      foreach ($ch in $o.Substring(1).ToCharArray()) {
        if ($ch -ceq 'f') { Block 'force push' }
        if ($ch -ceq 'o') { if ($o.EndsWith('o')) { $j++ }; break }
      }
      continue
    }
    if ($o.StartsWith('-')) { continue }
    $pos.Add($o)
  }
  foreach ($p in $pos) {
    if ($p.Contains('$') -or $p.Contains('`')) { Block 'a push target from a variable or command cannot be checked' }
  }
  $refs = @($pos | Select-Object -Skip 1)
  $current = $null
  if (-not $refs.Count) {
    if (Get-PushTargets $dir | Where-Object { Test-MainRef $_ }) { Block 'pushing to main (this branch pushes to main): open a pull request instead' }
    return
  }
  foreach ($r in $refs) {
    if ($r.StartsWith('+')) { Block 'force push' }
    $dst = if ($r.Contains(':')) { $r.Substring($r.LastIndexOf(':') + 1) } else { $r }
    if (Test-MainRef $dst) { Block 'pushing to main: open a pull request instead' }
    if ($dst -in 'HEAD', '@') {
      if ($null -eq $current) { $current = @(Get-PushTargets $dir) }
      if ($current | Where-Object { Test-MainRef $_ }) { Block 'pushing to main (HEAD is main): open a pull request instead' }
    }
  }
}

function Test-Git([string[]]$t, [int]$gi, [string]$dir, $drop, [int]$depth, [bool]$fromXargs) {
  # Global options before the subcommand (-C, -c, --git-dir, ...) are skipped, so `git -c x=y push` is a push.
  $k = $gi + 1
  while ($k -lt $t.Count -and $t[$k].StartsWith('-')) {
    $o = $t[$k]
    if ($o -ceq '-C' -and $k + 1 -lt $t.Count) { $dir = Resolve-Dir $dir $t[$k + 1]; $k += 2; continue }
    if (($o -ceq '-c' -or $o -eq '--config-env') -and $k + 1 -lt $t.Count) { Test-GitConfigKey $t[$k + 1]; $k += 2; continue }
    Test-GitConfigKey $o
    if ($o -in '--git-dir', '--work-tree', '--namespace' -and $k + 1 -lt $t.Count) { $k += 2; continue }
    $k++
  }
  if ($k -ge $t.Count) { return }
  $sub = $t[$k].ToLowerInvariant()
  $first = $k + 1
  $a = [string[]]@(if ($first -lt $t.Count) { $t[$first..($t.Count - 1)] })

  # An alias from the git config: check what it expands to.
  if ($sub -notin $GitBuiltins -and $sub -match '^[\w.-]+$') {
    $alias = $null
    try { $alias = & git -C $dir config --get "alias.$sub" 2>$null; if ($LASTEXITCODE -ne 0) { $alias = $null } } catch { $alias = $null }
    if ($alias) {
      $rest = ($a | ForEach-Object { "'" + ($_ -replace "'", "'\''") + "'" }) -join ' '
      $expanded = if ("$alias".StartsWith('!')) { "$alias".Substring(1) + ' ' + $rest } else { "git -C '$dir' $alias $rest" }
      Test-Command $expanded $dir ($depth + 1) $false
      return
    }
  }

  if ($a | Where-Object { $_.StartsWith('--') -and (Test-LongOption $_ '--no-verify') }) { Block '--no-verify would skip the gitleaks hook' }
  if ($sub -eq 'push') {
    if ($fromXargs) { Block 'git push with arguments from xargs cannot be checked' }
    Test-Push $a $dir
  }
  if ($sub -eq 'reset' -and ($a | Where-Object { $_.StartsWith('--') -and (Test-LongOption $_ '--hard') })) { Block 'git reset --hard throws work away' }
  if ($sub -eq 'config' -and -not ($a -match '^--(get|unset|list)') -and @($a | Where-Object { -not $_.StartsWith('-') }).Count -ge 2) {
    foreach ($x in $a) { if (-not $x.StartsWith('-')) { Test-GitConfigKey $x; break } }
  }
  if ($sub -in 'checkout', 'switch') {
    for ($j = 0; $j -lt $a.Count; $j++) {
      if ($a[$j] -cin '-b', '-B', '-c', '-C', '--orphan') { if ($j + 1 -lt $a.Count) { $script:switchedTo = $a[$j + 1] }; break }
      if ($a[$j] -eq '--') { break }
      if ($a[$j].StartsWith('-')) { continue }
      $script:switchedTo = $a[$j]
      break
    }
  }
  if ($sub -in 'commit', 'tag', 'merge', 'notes', 'stash') {
    $valueOpts = '--message', '--file', '--author', '--date', '--template', '--trailer', '--reuse-message', '--reedit-message', '--fixup', '--squash', '--cleanup'
    for ($j = 0; $j -lt $a.Count; $j++) {
      $o = $a[$j]
      $isMsg = $o -ceq '-m' -or $o -eq '--message'
      if ($isMsg -or $o -cin '-F', '-c', '-C', '-t' -or $o -in $valueOpts) {
        if ($isMsg -and $j + 1 -lt $a.Count -and (Test-DataValue $a[$j + 1])) { [void]$drop.Add($first + $j + 1) }
        $j++; continue
      }
      if ($o -match '^--message=' -and (Test-DataValue $o)) { [void]$drop.Add($first + $j); continue }
      if ($o -cmatch '^-[a-zA-Z]') {
        foreach ($ch in $o.Substring(1).ToCharArray()) {
          if ($ch -ceq 'n' -and $sub -eq 'commit') { Block '-n (--no-verify) would skip the gitleaks hook' }
          if ([string]$ch -cin 'm', 'F', 'c', 'C', 't') {
            if ($ch -ceq 'm') {
              if ($o.EndsWith('m')) { if ($j + 1 -lt $a.Count -and (Test-DataValue $a[$j + 1])) { [void]$drop.Add($first + $j + 1) }; $j++ }
              elseif (Test-DataValue $o) { [void]$drop.Add($first + $j) }
            }
            elseif ($o.EndsWith([string]$ch)) { $j++ }
            break
          }
        }
      }
    }
  }
}

function Test-Gh([string[]]$t, [int]$hi, $drop) {
  $first = $hi + 1
  $a = [string[]]@(if ($first -lt $t.Count) { $t[$first..($t.Count - 1)] })
  if (-not $a.Count) { return }
  $s0 = $a[0].ToLowerInvariant()
  $s1 = if ($a.Count -gt 1) { $a[1].ToLowerInvariant() } else { '' }
  $why = 'GitHub secrets, repo deletion and settings changes are for a person, not an agent'
  if ($s0 -eq 'secret') { Block $why }
  if ($s0 -eq 'repo' -and $s1 -in 'delete', 'edit', 'archive', 'rename') { Block $why }
  if ($s0 -eq 'variable' -and $s1 -in 'set', 'delete') { Block $why }
  if ($s0 -eq 'ruleset' -and $s1 -notin 'list', 'view', 'check', '') { Block $why }
  if ($s0 -eq 'auth' -and ($s1 -eq 'token' -or ($a | Where-Object { $_ -cin '-t', '--show-token' }))) { Block 'printing the GitHub token can leak it' }
  if ($s0 -eq 'api') {
    # gh api is a write when the method says so, or when it sends fields or a body without an explicit GET
    # (fields make gh default to POST). A GraphQL call is a write when it is a mutation or reads its query from a file.
    $method = $null; $fields = [System.Collections.Generic.List[string]]::new(); $hasInput = $false
    for ($j = 1; $j -lt $a.Count; $j++) {
      $o = $a[$j]
      if ($o -ceq '-X' -or $o -eq '--method') { $method = $a[$j + 1]; $j++; continue }
      if ($o -cmatch '^-X(?<m>.+)$' -or $o -match '^--method=(?<m>.+)$') { $method = $Matches.m; continue }
      if ($o -cin '-f', '-F' -or $o -in '--field', '--raw-field') { if ($j + 1 -lt $a.Count) { $fields.Add($a[$j + 1]) } else { $fields.Add('') }; $j++; continue }
      if ($o -cmatch '^-[fF](?<v>.+)$' -or $o -match '^--(raw-)?field=(?<v>.*)$') { $fields.Add($Matches.v); continue }
      if ($o -eq '--input' -or $o -match '^--input=') { $hasInput = $true; $j += [int]($o -eq '--input'); continue }
    }
    $endpoint = @($a | Select-Object -Skip 1 | Where-Object { -not $_.StartsWith('-') })[0]
    if ($method) {
      if ($method -notmatch '^(GET|HEAD)$') { Block $why }
    }
    elseif ($endpoint -eq 'graphql') {
      if ($hasInput -or ($fields | Where-Object { $_ -match '(?i)\bmutation\b' -or $_ -match '^[^=]*=@' })) { Block $why }
    }
    elseif ($fields.Count -or $hasInput) { Block "$why (gh api with fields is a POST)" }
  }
  if ($s0 -eq 'pr' -and $s1 -eq 'merge') { $script:askWhy = "Merging is a person's decision" }
  if ($s0 -in 'pr', 'issue', 'release') {
    for ($j = 2; $j -lt $a.Count; $j++) {
      if ($a[$j] -cin '--title', '-t', '--body', '-b', '--notes', '-n') {
        if ($j + 1 -lt $a.Count -and (Test-DataValue $a[$j + 1])) { [void]$drop.Add($first + $j + 1) }
        $j++
      }
      elseif ($a[$j] -match '^--(title|body|notes)=' -and (Test-DataValue $a[$j])) { [void]$drop.Add($first + $j) }
    }
  }
}

function Test-Command([string]$text, [string]$cwd, [int]$depth, [bool]$ps) {
  if ($depth -gt 4) { Block 'commands nested this deep cannot be checked' }
  $parsed = Split-Command $text $ps
  if ($parsed.Incomplete) { Test-LegacyRules $text; [void]$script:scan.AppendLine($text) }
  $segs = $parsed.Segs
  for ($si = 0; $si -lt $segs.Count; $si++) {
    $s = $segs[$si]
    $t = [string[]]@($s.Tokens)
    $names = [string[]]@($t | ForEach-Object { Get-Name $_ })
    $drop = [System.Collections.Generic.HashSet[int]]::new()
    $dataBodies = $false
    $bodiesDone = $false

    if ($names.Count -and $names[0] -in 'cd', 'chdir', 'pushd', 'set-location', 'sl', 'push-location') {
      $target = @($t | Select-Object -Skip 1 | Where-Object { -not $_.StartsWith('-') })
      if ($target.Count) { $cwd = Resolve-Dir $cwd $target[-1] }
    }

    # Printing the environment
    if ($names.Count -eq 1 -and $names[0] -in 'printenv', 'env', 'set') { Block 'printing the environment can leak connection strings and tokens' }
    if ($names.Count -and $names[0] -in 'printenv', 'env' -and ($t | Select-Object -Skip 1 | Where-Object { $_ -notmatch '=' -and $_ -match $SecretVar })) {
      Block 'reading secret environment variables can leak them'
    }
    if (($names | Where-Object { $_ -in 'get-childitem', 'gci', 'dir', 'ls', 'get-item', 'gi', 'get-content', 'gc', 'type', 'cat' }) -and ($t -match '(?i)^env:')) {
      Block 'printing the environment can leak connection strings and tokens'
    }

    # Every git and gh in the segment, also behind wrappers (env, sudo, command, xargs, ...)
    $xi = [array]::IndexOf($names, 'xargs')
    for ($k = 0; $k -lt $names.Count; $k++) {
      if ($names[$k] -eq 'git') { Test-Git $t $k $cwd $drop $depth ($xi -ge 0 -and $xi -lt $k); $dataBodies = $true }
      elseif ($names[$k] -eq 'gh') { Test-Gh $t $k $drop; $dataBodies = $true }
    }
    if ($names.Count -and $names[0] -in 'cat', 'tee', 'set-content', 'add-content', 'out-file') { $dataBodies = $true }

    # Start-Process git ...: check the arguments as a git command; ask if they come from a variable.
    $spi = -1
    for ($k = 0; $k -lt $names.Count; $k++) { if ($names[$k] -in 'start-process', 'saps') { $spi = $k; break } }
    if ($spi -ge 0 -and $spi + 1 -lt $t.Count) {
      $rest = @($t | Select-Object -Skip ($spi + 1) | Where-Object { -not $_.StartsWith('-') } | ForEach-Object { $_ -replace ',', ' ' })
      Test-Command ($rest -join ' ') $cwd ($depth + 1) $false
      if ($rest -match '\$') { $script:askWhy = 'Start-Process with arguments from a variable cannot be checked' }
    }

    # A shell or eval runs its arguments (and a heredoc fed to it) as commands: check those as commands.
    $shi = -1
    for ($k = 0; $k -lt $names.Count; $k++) { if ($names[$k] -in $Shells) { $shi = $k; break } }
    if ($shi -ge 0) {
      $inPs = $names[$shi] -in $PsShells
      for ($k = $shi + 1; $k -lt $t.Count; $k++) { Test-Command $t[$k] $cwd ($depth + 1) $inPs; [void]$drop.Add($k) }
      foreach ($b in $s.Bodies) { Test-Command $b.Text $cwd ($depth + 1) $inPs }
      $bodiesDone = $true
      if ($names[$shi] -in 'iex', 'invoke-expression' -and $text.Contains('$')) { $script:askWhy = 'Invoke-Expression of a variable cannot be checked' }
    }

    # Output piped into a shell (`cat <<EOF | sh`, `echo "..." | bash`): the arguments and heredocs are commands.
    if ($s.PipesOut -and $si + 1 -lt $segs.Count) {
      $next = [string[]]@($segs[$si + 1].Tokens | ForEach-Object { Get-Name $_ })
      $sh = @($next | Where-Object { $_ -in $Shells })
      if ($sh.Count) {
        $inPs = $sh[0] -in $PsShells
        for ($k = 1; $k -lt $t.Count; $k++) { Test-Command $t[$k] $cwd ($depth + 1) $inPs }
        foreach ($b in $s.Bodies) { Test-Command $b.Text $cwd ($depth + 1) $inPs }
      }
    }

    # Interpreter code (python -c, node -e, a heredoc fed to python): the parser can't read it, the old rules can.
    if ($names | Where-Object { $_ -in $Interpreters -or $_ -match '^python\d' }) {
      foreach ($x in $t) { Test-LegacyRules $x }
      foreach ($b in $s.Bodies) { Test-LegacyRules $b.Text }
    }

    # Existing migrations edited from the shell (sed -i, Set-Content, > redirect, ...)
    $writes = ($names | Where-Object { $_ -in $Writers }) -or ($t | Where-Object { $_ -match '^\d?>' })
    if ($writes) {
      foreach ($x in $t) {
        $p = ($x -replace '^\d?>>?', '') -replace '\\', '/'
        if ($p -match '(^|/)Migrations/[^/]+\.\w+$' -and (Test-Path -LiteralPath (Resolve-Dir $cwd $p))) { Block 'existing migrations are never edited; add a new migration' }
      }
    }

    for ($k = 0; $k -lt $t.Count; $k++) { if (-not $drop.Contains($k)) { [void]$script:scan.Append($t[$k]).Append(' ') } }
    [void]$script:scan.Append("`n")
    if (-not $bodiesDone) {
      foreach ($b in $s.Bodies) {
        if (-not $dataBodies -or ($b.Expands -and (Test-Expands $b.Text))) { [void]$script:scan.AppendLine($b.Text) }
      }
    }
  }
}

# --- The checks ------------------------------------------------------------------------------------------------

# 1. Secret files by path (Read, Edit, Glob, ...)
if (Test-SecretFile $paths) { Block 'secret files are off limits for agents' }

if ($cmd) {
  # 2. Secret environment variables, and git config from the environment. Checked on the raw command.
  if ($cmd -match "(?i)(\`$env:|\`$\{?|%)\w*$SecretVar\w*") { Block 'reading secret environment variables can leak them' }
  if ($cmd -match '(?i)\bGIT_CONFIG_(COUNT|KEY_\d+|VALUE_\d+|PARAMETERS|GLOBAL|SYSTEM)\b') { Block 'git config from environment variables can skip hooks or add aliases' }
  # 3. Git, GitHub, printing the environment and shell edits to migrations, per command. Message text (git commit
  #    -m, gh pr --body, a heredoc fed to git, gh or cat) is data and is left out of the secret-file check below.
  $cwd = if ($hook.cwd) { [string]$hook.cwd } else { (Get-Location).Path }
  try { Test-Command $cmd $cwd 0 ($tool -eq 'PowerShell') } catch { Test-LegacyRules $cmd; [void]$script:scan.Append($cmd) }
  # 4. Secret files named in the command (cat .env, Get-Content secrets.json, ...)
  if (Test-SecretFile $script:scan.ToString()) { Block 'secret files are off limits for agents' }
}

# 5. Folders the person guards (set per repo above)
foreach ($f in $AskFolders) {
  if ($all -match "(^|/)$([regex]::Escape($f))(/|$)") { $script:askWhy = "$f/ is a private folder: the person decides" }
}

# 6. Existing database migrations are never edited (add a new one instead)
if ($tool -in 'Edit', 'Write', 'MultiEdit' -and $ti.file_path) {
  $p = $ti.file_path -replace '\\', '/'
  if ($p -match '/Migrations/' -and (Test-Path -LiteralPath $ti.file_path)) { Block 'existing migrations are never edited; add a new migration' }
}

if ($script:askWhy) { Ask $script:askWhy }
exit 0
