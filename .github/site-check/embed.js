// Keeps the copies of package.json and package-lock.json inside .github/workflows/site-check.yml the same as the
// files next to this script. A called workflow cannot check out its own repo at its own commit, so it carries them.
//   node .github/site-check/embed.js          update the copies in the workflow
//   node .github/site-check/embed.js --check  fail when they differ (the Site check tools workflow)
const fs = require('fs');
const path = require('path');
const workflow = path.join(__dirname, '..', 'workflows', 'site-check.yml');
const parts = { PACKAGE_JSON: 'package.json', PACKAGE_LOCK: 'package-lock.json' };
const original = fs.readFileSync(workflow, 'utf8');
let text = original;
for (const [mark, file] of Object.entries(parts)) {
  const re = new RegExp(String.raw`(<<'${mark}'\n)([\s\S]*?)^( *)${mark}$`, 'm');
  const m = text.match(re);
  if (!m) { console.error(`site-check.yml has no <<'${mark}' ... ${mark} block.`); process.exit(1); }
  const indent = m[3];
  const body = fs.readFileSync(path.join(__dirname, file), 'utf8').replace(/\r\n/g, '\n').replace(/\n$/, '')
    .split('\n').map((l) => (l ? indent + l : l)).join('\n') + '\n';
  text = text.replace(re, (all, open, old, ind) => open + body + ind + mark);
}
if (process.argv.includes('--check')) {
  if (text !== original) {
    console.log('::error file=.github/workflows/site-check.yml::The copies of package.json or package-lock.json in site-check.yml differ from .github/site-check/. Run node .github/site-check/embed.js and commit.');
    process.exit(1);
  }
  console.log('site-check.yml carries the same package.json and package-lock.json as .github/site-check/.');
} else if (text !== original) {
  fs.writeFileSync(workflow, text);
  console.log('Updated the copies in site-check.yml.');
} else {
  console.log('site-check.yml is already up to date.');
}
