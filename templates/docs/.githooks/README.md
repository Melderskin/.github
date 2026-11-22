# Git hooks

`pre-commit` checks every commit for secrets (passwords, keys, tokens, connection strings) with [gitleaks](https://github.com/gitleaks/gitleaks), and stops the commit if it finds one. It is the free stand-in for GitHub's push protection: the secret never leaves your machine. CI runs gitleaks again over the whole history (the shared `secrets.yml` workflow), for clones where the hook is off.

## Turn it on (once per clone)

macOS and Linux (or Git Bash on Windows):

```bash
sh .githooks/install.sh
```

Windows (PowerShell):

```powershell
./.githooks/install.ps1
```

Both set `core.hooksPath` to `.githooks` for this clone, so `git config core.hooksPath .githooks` does the same on any OS. Git doesn't turn hooks on by itself when you clone, so every new clone needs this once.

The hook itself is a shell script on every OS: on Windows, git runs it with the `sh` that comes with Git for Windows, also when you commit from PowerShell, Visual Studio, Rider or VS Code.

## gitleaks

The hook uses `gitleaks` if it is installed, and otherwise the gitleaks Docker image (pinned by digest). With neither, the commit is stopped. The installed one is faster, since Docker starts a container for every commit.

| OS | Install |
|---|---|
| Windows | `winget install Gitleaks.Gitleaks` (or `scoop install gitleaks`) |
| macOS | `brew install gitleaks` |
| Linux | Download the binary for your machine from the [gitleaks releases](https://github.com/gitleaks/gitleaks/releases) and put it on your `PATH`, or use Docker (nothing to install) |

## When it stops a commit

1. Look at the file and line it names. The secret itself is redacted in the output.
2. Remove the secret from the file, and put it where secrets belong: a local secret store (for .NET, `dotnet user-secrets`), and GitHub secrets or the host's secret store in CI and hosting.
3. If the secret was ever real, **rotate it**: treat it as leaked, even though it wasn't committed.
4. Stage the file again and commit.

If it is a false positive (for example a test value that only looks like a key), add a `gitleaks:allow` comment on that line, and say why in the commit message. Don't use `git commit --no-verify` to get past it.
