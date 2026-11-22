# <App name> (for Claude)

<One or two sentences: what this app is, who uses it, and on which platforms (iOS, Android, web).>

## Commands

Every command works on Windows, macOS and Linux. Run `npm ci` once first.

| | Command | What it does |
|---|---|---|
| build | `npx expo export --platform web` | Builds the web version into `dist/` |
| test | `npm test` | <What the tests cover> |
| serve | `npx expo start` | Starts the dev server (press `w` for web, or scan the QR code with Expo Go) |
| check | `npx tsc --noEmit && npm test` | What CI runs before a pull request: types, tests, secrets |

## Rules

- **Dependencies:** install with `npm ci` (the exact versions in `package-lock.json`); add packages with `npx expo install` so they match the SDK.
- **Files:** LF everywhere (`.gitattributes`).
- **Work:** start on an issue that is ready; one issue per pull request.
- **Secrets:** the pre-commit hook runs gitleaks; turn it on once per clone (`.githooks/README.md`). Nothing secret goes in `app.json` or `app.config.js`: they ship inside the app.

## Never

- Commit passwords, keys or tokens, or skip the pre-commit hook.
- Push to `main` or force push. Commit and push only when asked.
- <Anything else this repo must never do.>
