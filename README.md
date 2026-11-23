# Melderskin defaults

Shared files for every Melderskin repo:

- **Issue templates** (`.github/ISSUE_TEMPLATE/`): **Task**, **Bug** and **Proposal**. GitHub uses them in every repo that has none of its own.
- **Claude Code locks** (`templates/claude/`): settings, a guard hook and a Stop hook to copy into every repo; see its README.
- **Repo templates per kind** (`templates/<kind>/`): the files a new repo starts from. See [Templates](#templates).
- **Reusable workflows** (`.github/workflows/`): `secrets.yml`, `dotnet-ci.yml`, `site-check.yml` and `confluence-publish.yml`. Each repo calls them from a small workflow of its own. See [Reusable workflows](#reusable-workflows).

This repo is public because GitHub only reads default files from a public `.github` repo, and a public reusable workflow can be called from the private repos. Never put code, plans, names of customers, secrets or anything internal here.

How we use issues, the labels and the rules for agents: `project/26-start-here.md` in the hub (`Melderskin/melderskin-hq`, private). Jira and Confluence: `project/27-jira-and-confluence.md`. In the hub this repo is cloned as `org-github/`.

To change a template or a workflow, change it here in a pull request. A repo that adds its own `.github/ISSUE_TEMPLATE/` stops using these templates, so don't, unless it really needs different ones.

## Templates

Four kinds: `dotnet` (C# and .NET), `site` (static sites), `expo` (Expo and React Native apps) and `docs` (Markdown only). Copy the folder of your kind into the new repo's root, fill in the `<placeholders>`, and turn the hook on with `sh .githooks/install.sh` (or `./.githooks/install.ps1`).

| File | Kinds | What it is |
|---|---|---|
| `CLAUDE.md` | all, one per kind | A skeleton for agents: what the repo is, the four commands (`build`, `test`, `serve`, `check`) and what never to do. Short; fill in the placeholders |
| `.editorconfig` | all; `dotnet` has its own | UTF-8, LF, final newline, two spaces (four for C# and PowerShell). The `dotnet` one has the place where analyzer rules are turned off, each with its reason |
| `.gitattributes` | all, the same | LF for every text file on every OS; images, fonts, PDFs and video are binary |
| `.githooks/pre-commit` | all, the same | gitleaks on the staged changes before every commit; uses an installed gitleaks or the Docker image (pinned by digest), and stops the commit if neither is there |
| `.githooks/install.sh`, `install.ps1` | all, the same | Turn the hook on once per clone (`core.hooksPath`), from bash or PowerShell |
| `.githooks/README.md` | all, the same | How to turn it on, install gitleaks per OS, and what to do when it stops a commit |
| `LICENSE` | all, the same | **A placeholder.** No licence is chosen yet; replace the file when one is |
| `.github/CODEOWNERS` | all, the same | `* @Melderskin/<team>`: put the owning team (not a person) in place of `<team>` |
| `build.ps1`, `test.ps1`, `serve.ps1` | all, one per kind | The first three of the four commands. .NET: `dotnet build`, `dotnet test` and `dotnet run` (fill in the project); sites: a copy of `src/` (replace it with the site's build), an internal-link check of `dist/` and a local server; Expo: the npm scripts; docs: "nothing to do" |
| `check.ps1` | all, the same | What CI runs, on your machine: build, test, the guard's tests, known vulnerable packages (.NET) and gitleaks over the history |
| `build.sh`, `test.sh`, `serve.sh`, `check.sh` | all, the same | Run the `.ps1` of the same name from bash |
| `.claude/` | all | From `templates/claude/`: `settings.<kind>.json` and the hooks |

The shared files must stay the same in every kind: the **Templates check** workflow (`.github/workflows/templates-check.yml`) fails a pull request where they differ. Change all four copies together. The same workflow runs the guard's tests and checks that the settings files are what `make-settings.js` writes.

The hub keeps the repos in step with these templates: its `sync-templates` script shows what differs in each repo and opens one pull request per repo, and `status-all` reports the drift.

## Reusable workflows

Callers pin each workflow to a full commit SHA, not `@main`, so a change here cannot change what runs in their repo without a pull request there; Dependabot (github-actions) keeps the pin fresh. Every action in these workflows is pinned by commit SHA, checkout keeps no credentials, and the jobs run with `contents: read`. Inputs reach the shell only through environment variables.

### `secrets.yml`: gitleaks over the whole history

For every kind. gitleaks (Docker image pinned by digest) over the full history (`fetch-depth: 0`), so a secret that was committed and removed is still found. No inputs.

The caller's `.gitleaks.toml` and `.gitleaksignore` are read from the pull request's base branch (or the default branch on a push), never from the commit being checked, so a pull request cannot allow its own secret: a change to them takes effect once it is merged. Without them, gitleaks uses its default rules.

The job fails unless gitleaks really checked the history: an error line in its log, a missing report or 0 commits scanned all fail it, since gitleaks can log a git error and still exit 0.

```yaml
name: Secrets
on:
  push:
    branches: [main]
  pull_request:
permissions:
  contents: read
jobs:
  gitleaks:
    uses: Melderskin/.github/.github/workflows/secrets.yml@<commit-sha> # main yyyy-mm-dd
```

### `dotnet-ci.yml`: restore, build, test

For the `dotnet` kind. Restore, build with warnings as errors, test, and fail on packages with known vulnerabilities (also transitive ones).

| Input | Default | What it does |
|---|---|---|
| `dotnet-version` | `10.0.x` | The SDK for `actions/setup-dotnet` |
| `os` | `["ubuntu-latest"]` | The runners, as a JSON list; each one is a job |
| `working-directory` | `.` | Where to run `dotnet`, relative to the repo |
| `configuration` | `Release` | The build configuration |
| `postgres` | `false` | Start PostgreSQL on `localhost:5432` for the tests (Linux only; trust auth, a throwaway database) |
| `postgres-image` | `postgres:16` | The image for that service |
| `test-db-variable` | empty | The environment variable that gets `Host=localhost;Username=postgres` |
| `vulnerable-packages` | `true` | Fail on a package with a known vulnerability |
| `coverage` | `false` | Collect coverage and write a summary to the run's page (needs `reportgenerator` in the repo's tool manifest) |
| `coverage-assembly-filters` | empty | `-assemblyfilters` for reportgenerator, e.g. `+MyApp.*;-MyApp.Tests` |
| `timeout-minutes` | `30` | Stop each job after this many minutes |
| `sibling-repository` | empty | `owner/name` of a second repo to check out next to this one; both land in folders named after their repo, so it must be another repo's name |

Secret: `sibling-token`, a fine-grained token with *Contents: read* on the sibling repo (only with `sibling-repository`; the job fails without it, so a green check means the tests ran). Pass it by name, never with `secrets: inherit`, which would hand every secret of the calling repo to this workflow:

```yaml
    with:
      sibling-repository: <owner>/<repo>
    secrets:
      sibling-token: ${{ secrets.<READ_TOKEN> }}
```

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
permissions:
  contents: read
jobs:
  dotnet:
    uses: Melderskin/.github/.github/workflows/dotnet-ci.yml@<commit-sha> # main yyyy-mm-dd
    with:
      postgres: true
      test-db-variable: MY_TEST_DB
```

### `confluence-publish.yml`: Markdown to Confluence

Copies a repo's Markdown to a Confluence space as a read-only copy; the token and settings stay in the calling repo or the organisation, never here. The caller and its inputs are at the top of the workflow file.

### `site-check.yml`: build, internal links, HTML, markers

For the `site` kind. Four steps, each shown on its own on the run's page, with a summary of each:

1. **Build:** runs the build command; fails if the output folder has no `.html` file, or was already in the repo before the build.
2. **Internal links:** every local `href`, `src`, `srcset` and `poster` in the built pages (root-relative or relative) must point to a file in the output folder. Offline: links with a scheme (`https:`, `mailto:`) are not fetched, so a pull request cannot make the runner call arbitrary URLs.
3. **HTML:** [html-validate](https://html-validate.org) at a fixed version, with rules for real errors only: unclosed or misnested tags, duplicate ids and attributes, a missing `alt` on images or `lang` on `<html>`, a missing doctype. The rules are in the workflow, so a config file in the site cannot loosen them.
4. **Markers:** the site's own production guard (`Assert-ProductionReady` in its `site-build.ps1`) lists every note left for the author, `[PLACEHOLDER]` and other mark it would stop on, as a warning. They do not fail the check, since pages are still being filled in; the production build stops on them before publishing.

Steps 2 to 4 run even when an earlier check fails, so one run shows every problem. Each check fails when it did nothing (no pages, no links, no report, no answer from the guard). No secrets.

The build step runs the calling repo's own code, which can change what the later steps see. So this check is a quality gate for honest mistakes, not a security boundary against a hostile pull request.

| Input | Default | What it does |
|---|---|---|
| `build-command` | `pwsh ./build.ps1` | The command that builds the site into `output-dir`, run with bash from the repo root |
| `output-dir` | `dist` | The folder the build writes |
| `guard-script` | `site-build.ps1` | The PowerShell file that defines `Assert-ProductionReady` |
| `timeout-minutes` | `15` | Stop the job after this many minutes |

html-validate and everything it pulls in are fixed by `.github/site-check/package-lock.json` (exact versions and integrity hashes) and installed with `npm ci --ignore-scripts`. A called workflow cannot check out its own repo at its own commit, so `site-check.yml` carries copies of `package.json` and `package-lock.json`. The **Site check tools** workflow (`.github/workflows/site-check-tools.yml`) fails a pull request where the copies differ from the files. Dependabot (npm, with a 7-day cooldown) updates the files; in its pull request, run `node .github/site-check/embed.js` and commit, which updates the copies.

```yaml
name: Build
on:
  push:
    branches: [main]
  pull_request:
permissions:
  contents: read
jobs:
  site:
    uses: Melderskin/.github/.github/workflows/site-check.yml@<commit-sha> # main yyyy-mm-dd
    with:
      build-command: pwsh ./build.ps1 -Test
```
