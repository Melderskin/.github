# Claude Code locks for every repo

The same guard rails in every Melderskin repo (Jira MEL-108; the plan is track B and C1 in the hub's `project/32-ahead-of-the-curve.md`). Copy them; change them here, in a pull request, so every repo can catch up.

| File | Goes to | What it does |
|---|---|---|
| `settings.<kind>.json` | `<repo>/.claude/settings.json` | Allow, ask and deny lists for the repo kind: `dotnet` (platform, LMS, CMS), `site` (the static sites), `expo` (Duo), `hub` (melderskin-hq) |
| `hooks/guard.ps1` | `<repo>/.claude/hooks/guard.ps1` | Blocks what the lists can miss: secret files, secret environment variables, force pushes, pushes to `main`, skipping the gitleaks hook, `reset --hard`, GitHub secrets and settings calls, edits to existing migrations. Asks before merging. The hub sets `$AskFolders = @('private', 'archive')` at the top |
| `hooks/stop-dotnet.ps1` | `<repo>/.claude/hooks/stop-tests.ps1` (.NET repos only) | The build and the tests must pass before an agent stops, when `src/` or `tests/` changed |
| `hooks/guard.tests.ps1` | stays here | 27 cases: each rule blocks, and a look-alike passes |
| `make-settings.js` | stays here | Writes the four settings files from one base: `node templates/claude/make-settings.js` |

## How the guard reads a command

It drops quoted text first (commit messages and PR bodies can't run anything), then checks each command in a chain on its own. So `git push -u origin claude/x && gh pr create --base main` passes, while `git push origin main` is blocked. Secret environment variables are checked on the raw command, quotes included.

## Check

```bash
pwsh -NoProfile -File templates/claude/hooks/guard.tests.ps1
```

```bash
pwsh -NoProfile -File templates/claude/hooks/guard.tests.ps1 ../oyonix-platform/.claude/hooks/guard.ps1
```

The second form tests a repo's copy, to find drift. Everything needs PowerShell 7 (`pwsh`) on Windows, macOS and Linux. This repo is public: no secrets, names or internal paths here.
