// Использование: node merge-settings.js <repoSettings> <liveSettings>
const fs = require('fs');
const path = require('path');

const [repoPath, livePath] = process.argv.slice(2);
if (!repoPath || !livePath) {
  console.error('Использование: node merge-settings.js <repoSettings> <liveSettings>');
  process.exit(2);
}

function readJson(p, fallback) {
  if (!fs.existsSync(p)) return fallback;
  const text = fs.readFileSync(p, 'utf8').replace(/^﻿/, '');
  if (!text.trim()) return fallback;
  return JSON.parse(text);
}

const isObj = (v) => v && typeof v === 'object' && !Array.isArray(v);

function deepMerge(base, over) {
  const out = isObj(base) ? { ...base } : {};
  for (const k of Object.keys(over)) {
    out[k] = isObj(over[k]) && isObj(out[k]) ? deepMerge(out[k], over[k]) : over[k];
  }
  return out;
}

const repo = readJson(repoPath, {});
const live = readJson(livePath, {});

if (repo.permissions && repo.permissions.defaultMode !== undefined) {
  live.permissions = isObj(live.permissions) ? live.permissions : {};
  live.permissions.defaultMode = repo.permissions.defaultMode;
}
for (const k of ['model', 'effortLevel', 'modelSettings']) {
  if (repo[k] !== undefined) live[k] = isObj(repo[k]) && isObj(live[k]) ? deepMerge(live[k], repo[k]) : repo[k];
}
if (isObj(repo.extraKnownMarketplaces)) {
  live.extraKnownMarketplaces = deepMerge(live.extraKnownMarketplaces, repo.extraKnownMarketplaces);
}
if (isObj(repo.enabledPlugins)) {
  live.enabledPlugins = { ...(isObj(live.enabledPlugins) ? live.enabledPlugins : {}), ...repo.enabledPlugins };
}

fs.mkdirSync(path.dirname(path.resolve(livePath)), { recursive: true });
fs.writeFileSync(livePath, JSON.stringify(live, null, 2) + '\n', 'utf8');
console.log('settings.json обновлён: ' + livePath);
