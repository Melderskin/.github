// Writes settings.<kind>.json from one base, so every repo kind gets the same locks.
// Run: node templates/claude/make-settings.js   (then copy the right file to <repo>/.claude/settings.json)
const fs = require("fs");
const path = require("path");

const both = (list) => list.flatMap((c) => [`Bash(${c})`, `PowerShell(${c})`]);

// The four commands every repo has (build, test, serve, check), as .sh and .ps1 scripts, with or without options.
const fourCommands = ["build", "test", "serve", "check"].flatMap((c) => [
  `bash ${c}.sh`, `bash ${c}.sh *`, `pwsh ./${c}.ps1`, `pwsh ./${c}.ps1 *`, `./${c}.ps1`, `./${c}.ps1 *`,
]);

const base = {
  allow: both([
    "git status", "git status *", "git diff", "git diff *", "git log", "git log *", "git show *",
    "git branch", "git branch *", "git fetch", "git fetch *", "git worktree list",
    "gh pr view *", "gh pr checks *", "gh pr list *", "gh pr diff *",
    "gh issue view *", "gh issue list *", "gh run list *", "gh run view *", "gh run watch *",
    ...fourCommands,
  ]),
  ask: [
    ...both(["gh pr merge *"]),
    "Edit(./.github/workflows/**)", "Edit(./.githooks/**)", "Edit(./.claude/**)",
  ],
  deny: [
    "Read(**/.env)", "Read(**/.env.*)", "Read(**/secrets.json)", "Read(**/*.pfx)", "Read(**/*.pem)", "Read(**/*.key)",
    "Read(./.claude/settings.local.json)",
    ...both([
      "git push --force*", "git push -f *", "git push * --force*", "git push origin main*",
      "git reset --hard*", "git commit --no-verify*", "git commit * --no-verify*",
      "gh secret *", "gh repo delete *", "gh release *", "rm -rf *", "printenv*",
    ]),
  ],
};

const kinds = {
  dotnet: {
    allow: both([
      "dotnet build", "dotnet build *", "dotnet restore", "dotnet restore *", "dotnet test", "dotnet test *",
      "dotnet run *", "dotnet format *", "docker compose ps", "docker compose ps *", "docker compose logs *",
      "docker compose up *", "docker compose build *", "docker compose down", "docker ps", "docker ps *",
    ]),
    ask: both(["dotnet ef *", "docker compose down -v*"]),
    deny: both(["dotnet user-secrets list*", "dotnet ef database drop*"]),
    stop: "stop-tests.ps1",
  },
  // Sites deploy only from their workflows (test-site.yml, loopia.yml); there is no deploy script to allow.
  site: { allow: [], ask: [], deny: [] },
  expo: {
    allow: both(["npm ci", "npm install", "npm test", "npm test *", "npm run *", "npx expo start*", "npx expo export*", "npx tsc *"]),
    ask: both(["npx expo publish*", "eas *", "npm publish*"]),
    deny: [],
  },
  docs: { allow: [], ask: [], deny: [] },
  hub: {
    // sync-templates is allowed only as a dry run: with -Pr it pushes branches and opens pull requests, so it asks.
    allow: both([
      "bash status-all.sh*", "pwsh ./status-all.ps1*", "bash test-all.sh*", "pwsh ./test-all.ps1*",
      "bash clone-all.sh*", "bash sync-templates.sh", "pwsh ./sync-templates.ps1",
    ]),
    ask: [],
    deny: [],
  },
};

const hook = (file, timeout) => ({
  type: "command",
  command: `pwsh -NoProfile -File "$CLAUDE_PROJECT_DIR/.claude/hooks/${file}"`,
  timeout,
});

for (const [kind, k] of Object.entries(kinds)) {
  const settings = {
    $schema: "https://json.schemastore.org/claude-code-settings.json",
    permissions: {
      allow: [...base.allow, ...k.allow],
      ask: [...base.ask, ...k.ask],
      deny: [...base.deny, ...k.deny],
    },
    hooks: {
      PreToolUse: [{ matcher: "Read|Edit|Write|MultiEdit|Grep|Glob|Bash|PowerShell", hooks: [hook("guard.ps1", 15)] }],
      ...(k.stop ? { Stop: [{ hooks: [hook(k.stop, 600)] }] } : {}),
    },
  };
  fs.writeFileSync(path.join(__dirname, `settings.${kind}.json`), JSON.stringify(settings, null, 2) + "\n");
  console.log(`settings.${kind}.json: ${settings.permissions.allow.length} allow, ${settings.permissions.ask.length} ask, ${settings.permissions.deny.length} deny`);
}
