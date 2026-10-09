// Использование: node export-plugins.js <plugins.json> [--stdout]
// Читает JSON из `claude plugin list --json` (stdin или вызов claude) и обновляет plugins.json
const fs = require('fs');
const { execSync } = require('child_process');

const args = process.argv.slice(2);
const toStdout = args.includes('--stdout');
const target = args.find((a) => !a.startsWith('--')) || require('path').join(__dirname, '..', 'plugins.json');

let list;
try {
  list = JSON.parse(execSync('claude plugin list --json', { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 1 << 26 }));
} catch (e) {
  console.error('Не удалось получить список плагинов: ' + e.message);
  process.exit(1);
}

let prev = {};
if (fs.existsSync(target)) {
  try { prev = JSON.parse(fs.readFileSync(target, 'utf8').replace(/^﻿/, '')); } catch (e) { prev = {}; }
}

const out = { marketplaces: prev.marketplaces || [], enabled: [], disabled: [], disabledSynced: [] };
// Плагины @synced приходят из аккаунта claude.ai и могут не попасть в список: сохраняем прежние
const syncedOn = new Set();
for (const p of list) {
  if (p.scope !== 'user' || !p.id) continue;
  if (p.id.endsWith('@synced')) {
    if (p.enabled === false) out.disabledSynced.push(p.id);
    else syncedOn.add(p.id);
  } else if (p.enabled) out.enabled.push(p.id);
  else out.disabled.push(p.id);
}

for (const id of prev.disabledSynced || []) {
  if (!syncedOn.has(id) && !out.disabledSynced.includes(id)) out.disabledSynced.push(id);
}

const json = JSON.stringify(out, null, 2) + '\n';
if (toStdout) process.stdout.write(json);
else {
  fs.writeFileSync(target, json, 'utf8');
  console.log('plugins.json обновлён: ' + target);
}
