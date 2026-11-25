#!/usr/bin/env node
// check-requires.js — статическая проверка: все ли модули, на которые ссылается
// код в src/, существуют файлами. Ловит случаи, когда пакет обновления не привёз
// зависимость (частый источник ошибок при наложении нескольких апдейтов).
'use strict';
const fs = require('fs');
const path = require('path');

const SRC = 'C:\\Users\\artem\\KlinokPamyati\\src';

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (entry.name.endsWith('.lua')) out.push(full);
  }
  return out;
}

// Карта: путь модуля (например "Shared/Config/Talents") -> файл
const files = walk(SRC);
const known = new Set();
for (const file of files) {
  const rel = path.relative(SRC, file).replace(/\\/g, '/');
  // "ReplicatedStorage/Shared/Config/Talents.lua" -> "Shared/Config/Talents"
  const parts = rel.split('/');
  const service = parts.shift();
  const withoutExt = parts.join('/').replace(/\.lua$/, '').replace(/\.(server|client)$/, '');
  known.add(service + '/' + withoutExt);
  known.add(withoutExt);
}

const problems = [];
const pattern = /require\s*\(\s*([A-Za-z0-9_\.]+)\s*\)/g;

for (const file of files) {
  const text = fs.readFileSync(file, 'utf8');
  const rel = path.relative(SRC, file).replace(/\\/g, '/');
  let match;
  pattern.lastIndex = 0;
  while ((match = pattern.exec(text)) !== null) {
    const name = match[1];
    // Интересуют только обращения через сервисы/Shared/Systems, не script.Parent
    if (name.startsWith('script') || name.startsWith('game')) continue;
    if (!/^(Shared|Systems|Controllers|Lib|Windows|Hub|Net|Util|Config|Anim|Voxel|Fx)\./.test(name)) continue;
    const asPath = name.replace(/\./g, '/');
    const candidates = [asPath, 'ReplicatedStorage/' + asPath, 'ServerScriptService/' + asPath, 'StarterPlayer/StarterPlayerScripts/' + asPath];
    const found = candidates.some((candidate) => known.has(candidate));
    if (!found) problems.push(`${rel}: require(${name})`);
  }
}

console.log(`файлов проверено: ${files.length}, подозрительных require: ${problems.length}`);
for (const item of problems.slice(0, 40)) console.log('  ' + item);
process.exit(problems.length === 0 ? 0 : 0);
