// Использование: node merge-vscode.js <vscodeSettingsPath>
const fs = require('fs');

const p = process.argv[2];
if (!p || !fs.existsSync(p)) {
  console.log('Файл настроек VS Code не найден, пропускаю.');
  process.exit(0);
}

const KEY = 'claudeCode.initialPermissionMode';
const text = fs.readFileSync(p, 'utf8').replace(/^﻿/, '');

// Убирает // и /* */ комментарии вне строк, затем запятые перед } и ]
function clean(src) {
  let out = '';
  let i = 0;
  let inStr = false;
  while (i < src.length) {
    const c = src[i];
    const n = src[i + 1];
    if (inStr) {
      out += c;
      if (c === '\\') { out += n === undefined ? '' : n; i += 2; continue; }
      if (c === '"') inStr = false;
      i++;
    } else if (c === '"') {
      inStr = true; out += c; i++;
    } else if (c === '/' && n === '/') {
      while (i < src.length && src[i] !== '\n') i++;
    } else if (c === '/' && n === '*') {
      i += 2;
      while (i < src.length && !(src[i] === '*' && src[i + 1] === '/')) i++;
      i += 2;
    } else {
      out += c; i++;
    }
  }
  // убрать запятые перед закрывающей скобкой (вне строк)
  let res = '';
  inStr = false;
  for (let j = 0; j < out.length; j++) {
    const c = out[j];
    if (inStr) {
      res += c;
      if (c === '\\') { res += out[j + 1] || ''; j++; }
      else if (c === '"') inStr = false;
    } else if (c === '"') {
      inStr = true; res += c;
    } else if (c === ',') {
      let k = j + 1;
      while (k < out.length && /\s/.test(out[k])) k++;
      if (out[k] === '}' || out[k] === ']') continue;
      res += c;
    } else {
      res += c;
    }
  }
  return res;
}

let obj;
let hadComments = false;
try {
  obj = JSON.parse(text);
} catch (e) {
  try {
    obj = JSON.parse(clean(text));
    hadComments = true;
  } catch (e2) {
    console.log('ВНИМАНИЕ: не удалось разобрать настройки VS Code (' + p + ').');
    console.log('Добавь вручную строку: "' + KEY + '": "plan"');
    process.exit(0);
  }
}

if (obj === null || typeof obj !== 'object' || Array.isArray(obj)) {
  console.log('ВНИМАНИЕ: неожиданный формат настроек VS Code. Добавь вручную: "' + KEY + '": "plan"');
  process.exit(0);
}

if (obj[KEY] === 'plan') {
  console.log('VS Code: режим плана уже включён.');
  process.exit(0);
}
obj[KEY] = 'plan';
if (hadComments) fs.copyFileSync(p, p + '.bak');
fs.writeFileSync(p, JSON.stringify(obj, null, 4) + '\n', 'utf8');
console.log('VS Code: включён режим плана' + (hadComments ? ' (комментарии удалены, копия в settings.json.bak)' : '') + '.');
