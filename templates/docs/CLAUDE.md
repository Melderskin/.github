# <Repo name> (for Claude)

<One or two sentences: what these docs are, who reads them, and where they are published.>

## Commands

Every command works on Windows, macOS and Linux. Where bash and PowerShell differ, give both.

| | Command | What it does |
|---|---|---|
| build | `bash build.sh` / `pwsh ./build.ps1` | Nothing to build: the Markdown is the source |
| test | `bash test.sh` / `pwsh ./test.ps1` | <What the tests check, or "nothing to test"> |
| serve | `bash serve.sh` / `pwsh ./serve.ps1` | Nothing to serve: read the Markdown on GitHub |
| check | `bash check.sh` / `pwsh ./check.ps1` | What CI runs before a pull request: build, test, the guard's tests and gitleaks over the history. The same script in every repo |

## Rules

- **Writing:** <the style guide, the languages, who the reader is>.
- **Structure:** <where new pages go, and the index that lists them>.
- **Files:** LF everywhere (`.gitattributes`).
- **Work:** start on an issue that is ready; one issue per pull request.
- **Secrets:** the pre-commit hook runs gitleaks; turn it on once per clone (`.githooks/README.md`).

## Never

- Commit passwords, keys, tokens or webhook URLs, or skip the pre-commit hook.
- Push to `main` or force push. Commit and push only when asked.
- <Anything else this repo must never do.>
