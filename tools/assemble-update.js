// assemble-update.js — раскладывает извлечённые из KlinokUpdate.rbxmx исходники
// в дерево src/ проекта, чтобы залить их в Studio через sync.js.
//
// Соответствие классов и суффиксов:
//   Script        -> *.server.lua
//   LocalScript   -> *.client.lua
//   ModuleScript  -> *.lua
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = 'C:\\Users\\artem\\KlinokPamyati';
const EXTRACTED = path.join(ROOT, 'docs', 'update_sources', 'Sources');
const SRC = path.join(ROOT, 'src');

// Куда какой каталог обновления ложится в src/
const MAP = [
  { from: path.join('ReplicatedStorage'), to: path.join(SRC, 'ReplicatedStorage') },
  { from: path.join('ServerScriptService'), to: path.join(SRC, 'ServerScriptService') },
  { from: path.join('StarterPlayerScripts'), to: path.join(SRC, 'StarterPlayer', 'StarterPlayerScripts') },
];

function suffixFor(fileName) {
  const guess = fileName;
  return guess;
}

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else out.push(full);
  }
  return out;
}

// Классы берём из индекса, который записал extract-rbxmx.ps1.
function readIndex() {
  const indexFile = path.join(ROOT, 'docs', 'update_sources', '_index.txt');
  const map = new Map();
  for (const line of fs.readFileSync(indexFile, 'utf8').split(/\r?\n/)) {
    if (!line.trim()) continue;
    const [className, name, file] = line.split('|');
    map.set(file.replace(/\\/g, '/').toLowerCase(), { className, name, file });
  }
  return map;
}

const index = readIndex();
const report = [];

for (const mapping of MAP) {
  const fromRoot = path.join(EXTRACTED, mapping.from);
  if (!fs.existsSync(fromRoot)) {
    report.push(`НЕТ КАТАЛОГА: ${fromRoot}`);
    continue;
  }

  for (const file of walk(fromRoot)) {
    if (!file.endsWith('_source.lua')) continue;
    const key = file.replace(/\\/g, '/').toLowerCase();
    const entry = index.get(key);
    if (!entry) {
      report.push(`нет в индексе: ${file}`);
      continue;
    }

    // В выгрузке каждый модуль лежит в своей папке: Config/Binds/_source.lua.
    // Значит контейнер — это родитель папки модуля, а имя файла — имя модуля.
    const moduleDir = path.dirname(file);
    const relDir = path.relative(fromRoot, path.dirname(moduleDir));
    const name = entry.name;
    let fileName;
    if (entry.className === 'Script') fileName = `${name}.server.lua`;
    else if (entry.className === 'LocalScript') fileName = `${name}.client.lua`;
    else fileName = `${name}.lua`;

    const targetDir = path.join(mapping.to, relDir);
    fs.mkdirSync(targetDir, { recursive: true });
    const target = path.join(targetDir, fileName);

    const text = fs.readFileSync(file, 'utf8');
    fs.writeFileSync(target, text, 'utf8');
    report.push(`ok ${entry.className.padEnd(12)} ${path.relative(SRC, target)}`);
  }
}

console.log(report.join('\n'));
console.log(`\nвсего файлов: ${report.filter((line) => line.startsWith('ok')).length}`);
