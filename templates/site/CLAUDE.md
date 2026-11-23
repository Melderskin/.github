# <Site name> (for Claude)

<One or two sentences: what this site is, who reads it, and where it is published.>

## Commands

Every command works on Windows, macOS and Linux. Where bash and PowerShell differ, give both.

| | Command | What it does |
|---|---|---|
| build | `bash build.sh` / `pwsh ./build.ps1` | Builds the site into `dist/` |
| test | `bash test.sh` / `pwsh ./test.ps1` | Builds and checks every internal link in `dist/` (CI also checks the HTML, notes and placeholders) |
| serve | `bash serve.sh` / `pwsh ./serve.ps1` | Serves `dist/` on <http://localhost:port> |
| check | `bash check.sh` / `pwsh ./check.ps1` | What CI runs before a pull request: build, test, the guard's tests and gitleaks over the history. The same script in every repo |

## Rules

- **Languages:** <the languages of the site>. Change every language when you change a page.
- **Accessibility:** WCAG 2.2 AA.
- **Files:** LF everywhere (`.gitattributes`).
- **Work:** start on an issue that is ready; one issue per pull request.
- **Secrets:** the pre-commit hook runs gitleaks; turn it on once per clone (`.githooks/README.md`).

## Never

- Commit passwords, keys, tokens or webhook URLs, or skip the pre-commit hook.
- Push to `main` or force push. Commit and push only when asked.
- Deploy by hand outside the deploy workflow.
- <Anything else this repo must never do.>
