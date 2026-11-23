# <App name> (for Claude)

<One or two sentences: what this app is, who uses it, and on which platforms (iOS, Android, web).>

## Commands

Every command works on Windows, macOS and Linux. Run `npm ci` once first.

| | Command | What it does |
|---|---|---|
| build | `npm run build` (or `bash build.sh` / `pwsh ./build.ps1`) | Builds the web version into `dist/` |
| test | `npm test` (or `bash test.sh` / `pwsh ./test.ps1`) | <What the tests cover> |
| serve | `npm run serve` (or `bash serve.sh` / `pwsh ./serve.ps1`) | Starts the dev server (press `w` for web, or scan the QR code with Expo Go) |
| check | `bash check.sh` / `pwsh ./check.ps1` | What CI runs before a pull request: build, test, the guard's tests and gitleaks over the history. The same script in every repo |

## Rules

- **Dependencies:** install with `npm ci` (the exact versions in `package-lock.json`); add packages with `npx expo install` so they match the SDK.
- **Files:** LF everywhere (`.gitattributes`).
- **Work:** start on an issue that is ready; one issue per pull request.
- **Secrets:** the pre-commit hook runs gitleaks; turn it on once per clone (`.githooks/README.md`). Nothing secret goes in `app.json` or `app.config.js`: they ship inside the app.

## Never

- Commit passwords, keys or tokens, or skip the pre-commit hook.
- Push to `main` or force push. Commit and push only when asked.
- <Anything else this repo must never do.>
