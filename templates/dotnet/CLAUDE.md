# <Repo name> (for Claude)

<One or two sentences: what this repo is, who uses it, and what it builds on.>

## Commands

Every command works on Windows, macOS and Linux. Where bash and PowerShell differ, give both.

| | Command | What it does |
|---|---|---|
| build | `dotnet build -c Release` | Builds everything. Warnings are errors |
| test | `dotnet test -c Release` | Runs the tests. <Say what they need, for example a database in an environment variable> |
| serve | `dotnet run --project src/<App>` | Runs the app locally on <http://localhost:port> |
| check | `<command>` | What CI runs: build, test, known vulnerable packages, secrets. Run it before a pull request |

## Rules

- **Code:** <.NET version>, warnings are errors and the .NET quality and security analyzers are on: fix a finding, or turn the rule off in `.editorconfig` with the reason.
- **Files:** LF everywhere (`.gitattributes`); never let behaviour depend on line endings or path separators.
- **Work:** start on an issue that is ready; one issue per pull request.
- **Secrets:** the pre-commit hook runs gitleaks; turn it on once per clone (`.githooks/README.md`).

## Never

- Commit passwords, keys, tokens or connection strings, or skip the pre-commit hook.
- Push to `main` or force push. Commit and push only when asked.
- Edit a migration that is already merged.
- <Anything else this repo must never do.>
