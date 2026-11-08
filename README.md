# Melderskin defaults

Shared files for every Melderskin repo:

- **Issue templates** (`.github/ISSUE_TEMPLATE/`): **Task**, **Bug** and **Proposal**. GitHub uses them in every repo that has none of its own.
- **Claude Code locks** (`templates/claude/`): settings, a guard hook and a Stop hook to copy into every repo; see its README.
- **The Confluence publish workflow** (`.github/workflows/confluence-publish.yml`): copies a repo's Markdown to a Confluence space as a read-only copy. Each repo calls it from a small workflow of its own; the token and settings stay in the calling repo or the organisation, never here.

This repo is public because GitHub only reads default files from a public `.github` repo, and a public reusable workflow can be called from the private repos. Never put code, plans, names of customers, secrets or anything internal here.

How we use issues, the labels and the rules for agents: `project/26-start-here.md` in the hub (`Melderskin/melderskin-hq`, private). Jira and Confluence: `project/27-jira-and-confluence.md`. In the hub this repo is cloned as `org-github/`.

To change a template or the workflow, change it here in a pull request. A repo that adds its own `.github/ISSUE_TEMPLATE/` stops using these templates, so don't, unless it really needs different ones.
