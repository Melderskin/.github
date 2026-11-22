# Melderskin defaults

Shared files for every Melderskin repo:

- **Issue templates** (`.github/ISSUE_TEMPLATE/`): **Task**, **Bug** and **Proposal**. GitHub uses them in every repo that has none of its own.
- **Claude Code locks** (`templates/claude/`): settings, a guard hook and a Stop hook to copy into every repo; see its README.
- **Repo templates per kind** (`templates/<kind>/`): the files a new repo starts from. See [Templates](#templates).
- **Reusable workflows** (`.github/workflows/`): `secrets.yml`, `dotnet-ci.yml` and `confluence-publish.yml`. Each repo calls them from a small workflow of its own. See [Reusable workflows](#reusable-workflows).

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
| `.claude/` | all | From `templates/claude/`: `settings.<kind>.json` and the hooks |

The shared files must stay the same in every kind: the **Templates check** workflow (`.github/workflows/templates-check.yml`) fails a pull request where they differ. Change all four copies together.

## Reusable workflows

Callers pin each workflow to a full commit SHA, not `@main`, so a change here cannot change what runs in their repo without a pull request there; Dependabot (github-actions) keeps the pin fresh. Every action in these workflows is pinned by commit SHA, checkout keeps no credentials, and the jobs run with `contents: read`. Inputs reach the shell only through environment variables.

### `secrets.yml`: gitleaks over the whole history

For every kind. gitleaks (Docker image pinned by digest) over the full history (`fetch-depth: 0`), so a secret that was committed and removed is still found. A `.gitleaks.toml` in the caller's root is used if it is there. No inputs.

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
| `sibling-repository` | empty | `owner/name` of a second repo to check out next to this one; both land in folders named after their repo |

Secret: `sibling-token`, a fine-grained token with *Contents: read* on the sibling repo (only with `sibling-repository`; the job fails without it, so a green check means the tests ran).

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

### Site check

A shared check for the `site` kind is planned (tracked separately); it will be listed here when it lands.
