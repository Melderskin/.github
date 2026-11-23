# Claude Code locks for every repo

The same guard rails in every Melderskin repo (Jira MEL-108; the plan is track B and C1 in the hub's `project/32-ahead-of-the-curve.md`). Copy them; change them here, in a pull request, so every repo can catch up.

| File | Goes to | What it does |
|---|---|---|
| `settings.<kind>.json` | `<repo>/.claude/settings.json` | Allow, ask and deny lists for the repo kind: `dotnet` (platform, LMS, CMS, the gate), `site` (the static sites), `expo` (Duo), `docs` (Markdown-only repos), `hub` (melderskin-hq). Every kind allows the four commands (`build`, `test`, `serve`, `check`, as `.sh` and `.ps1`) |
| `hooks/guard.ps1` | `<repo>/.claude/hooks/guard.ps1` | Blocks what the lists can miss: secret files, secret environment variables, force pushes, pushes to `main`, skipping the gitleaks hook, `reset --hard`, GitHub secrets and settings calls, edits to existing migrations. Asks before merging. One file for every repo: `$AskFolders` at the top names the folders where the person is asked first (`private` and `archive`, which only the hub has) |
| `hooks/stop-tests.ps1` | `<repo>/.claude/hooks/stop-tests.ps1` (.NET repos only) | The build and the tests must pass before an agent stops, when `src/` or `tests/` changed |
| `hooks/guard.tests.ps1` | `<repo>/.claude/hooks/guard.tests.ps1` | 156 cases: each rule blocks, and a look-alike passes. Each repo runs them in CI, so a broken copy is caught where it is used |
| `make-settings.js` | stays here | Writes the five settings files from one base: `node templates/claude/make-settings.js` |

## A repo's own rules

A repo that needs more than its kind allows (oyonix-platform's Docker setup commands, for example) lists them in `<repo>/.claude/settings.repo.json`, with the same `permissions` shape (`allow`, `ask`, `deny`). The hub's `sync-templates` script writes `settings.json` as the kind's file plus those lists, so the repo gets every later change to the base and keeps its own rules. It only adds: a repo can't remove a `deny` or an `ask` from the base. Edit `settings.repo.json`, never `settings.json`, which the next sync replaces.

## How the guard reads a command

It splits a command into tokens and commands the way the shell would (bash or PowerShell quoting, comments, heredocs, `&&`, `||`, `;`, pipes), and each rule looks only at its own command, so commit messages and PR bodies can't trip or bypass it. If the parser can't read a command, the older whole-string rules run as well (fail closed). So `git push -u origin claude/x && gh pr create --base main` passes, while `git push origin main` is blocked. Secret environment variables are checked on the raw command, quotes included.

## Check

```bash
pwsh -NoProfile -File templates/claude/hooks/guard.tests.ps1
```

```bash
pwsh -NoProfile -File templates/claude/hooks/guard.tests.ps1 ../oyonix-platform/.claude/hooks/guard.ps1
```

The second form tests a repo's copy, to find drift. Everything needs PowerShell 7 (`pwsh`) on Windows, macOS and Linux. This repo is public: no secrets, names or internal paths here.
